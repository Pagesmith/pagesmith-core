package Pagesmith::Adaptor::Event;

## Adaptor for comments database
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Adaptor);


my %filter_map = (
  'cat_id'   => 'c.category_id = ?',
  'brand_id' => 'b.brand_id    = ?',
  'type_id'  => 't.type_id     = ?',
  'status'   => 'e.status      = ?',
  'cat'      => 'c.code        = ?',
  'brand'    => 'b.code        = ?',
  'type'     => 't.code        = ?',
  'id'       => 'e.event_id    = ?',
  'before'   => 'e.start_date  <= ?',
  'st_before' => 'e.start_date  < ?',
  'after'    => 'e.end_date    >= ?',
  'search'   => 'e._search_    like concat("%",?,"%")',
);

use Pagesmith::Object::Event;

sub get_admin_by_id {
  my( $self, $id ) = @_;
  return $self->sv( 'select email from admin where admin_id = ?', $id );
}

sub authorize_admin {
  my( $self, $email ) = @_;
  return $self->{'_admin_id'} = $self->sv( 'select admin_id from admin where email = ? and status="active"', $email );
}

sub admin_id {
  my $self = shift;
  return $self->{'_admin_id'};
}

sub get_days_with_events {
  my( $self, $year, $month ) = @_;
  my $date = sprintf '%04d-%02d-01', $year, $month;
  my $endd = sprintf '%04d-%02d-31', $year, $month;
  my $events = $self->all_hash( 'select distinct start_date, end_date from event where status = "active" and end_date >= ? and start_date < adddate( ?, interval 1 month)',
    $date, $date );
  my %res;
  foreach my $event (@{$events}) {
    my $start = $event->{'start_date'} lt $date ? $date : $event->{'start_date'};
    my $end   = $event->{'end_date'}   gt $endd ? $endd : $event->{'end_date'};
    $start = substr $start,- 2,2;
    $end   = substr $end,- 2,2;
    foreach( $start..$end ) {
      $res{$_}++;
    }
  }
  return \%res;
}
sub _connection_pars {
  return 'hinxton';
}

sub get_brand_details {
  my( $self, $brand_id ) = @_;
  return $self->row_hash( 'select * from brand where brand_id=?', $brand_id );
}

## no critic (ImplicitNewlines)
sub get_brands {
  my $self = shift;
  return $self->all_hash(
    'select brand_id, code, name
       from brand
      order by name' );
}

sub get_brands_with_future_events {
  my $self = shift;
  return $self->all_hash(
    'select b.brand_id, b.code, b.name, count(*) as n
       from category c, brand b, event e
      where c.status ="active" and c.brand_id = b.brand_id and e.category_id = c.category_id and
            e.end_date >= now()
      group by b.brand_id
      order by b.brand_id' );
}

sub get_category_details {
  my( $self, $category_id ) = @_;
  return $self->row_hash( 'select b.code as brand_code, b.name as brand_name, c.* from brand as b, category as c
    where b.brand_id = c.brand_id and c.category_id = ?', $category_id );
}

sub get_categories {
  my $self = shift;
  return $self->hash(
    'select c.category_id, concat( c.name, " [",b.name,"]") as name
       from category c, brand b
      where c.status ="active" and c.brand_id = b.brand_id
      order by name' );
}

sub get_titles {
  my $self = shift;
  return $self->hash( 'select title_id,name from title order by name' );
}

sub get_types {
  my $self = shift;
  return $self->hash( 'select type_id,name from type order by name' );
}

sub get_types_with_future_events {
  my $self = shift;
  return $self->hash( 'select distinct t.type_id,t.name from type t,event e where e.type_id =t.type_id and e.end_date >= now() order by t.name' );
}

sub get_type_details {
  my( $self, $type_id ) = @_;
  return $self->row_hash( 'select * from type where type_id=?', $type_id );
}

sub get_locations {
  my $self = shift;
  return $self->hash( 'select location_id,name from location order by name' );
}

sub get_events {
  my ($self, $filters ) = @_;
  $filters ||= {qw(status active)};
  my @params;
  my $sql = '
  select c.brand_id, c.name as category, b.code as brand_code, b.name as brand, t.name as type,
         l.name as location, tt.name as speaker_title, e.*
    from ( brand as b, category c, type t, location l, event e ) left join title as tt on e.title_id = tt.title_id
   where b.brand_id = c.brand_id and c.category_id = e.category_id and t.type_id = e.type_id and
         l.location_id = e.location_id';

  foreach ( grep { exists $filter_map{$_} } keys %{$filters} ) {
    $sql .= ' and '.$filter_map{$_};
    push @params, $filters->{$_};
  }
  $sql .= ' order by e.start_date, e.end_date, e.title, e.event_id';
  return $self->all_hash( $sql, @params );
}

## use critic

sub fetch_events {
  my ($self, $filters ) = @_;
  return [ map { Pagesmith::Object::Event->new( $self, $_ ) } @{$self->get_events( $filters )} ];
}

sub fetch_all_admin {
  my $self = shift;
  return $self->fetch_events({});
}

sub fetch_all {
  my $self = shift;
  return $self->fetch_events();
}

sub fetch {
  my ($self, $id ) = @_;
  my $events = $self->fetch_events({ 'id'=>$id });
  return unless @{$events};
  return $events->[0];
}

sub create {
#@param (self)
#@param (hashref)? Optional hashref of attributes
#@return (Sange::Web:;Object::Feedback)
## Create a new event object
  my( $self, @pars ) = @_;
  return Pagesmith::Object::Event->new( $self, @pars );
}

sub store {
  my( $self, $event ) = @_;
  my $now      = $self->now;
  my $admin_id = 0;
  unless( $event->id ) {
    ## We need to populate location, brand, category, type && speaker_title
  }
  my $search_string = join q( ), grep { $_ }
    $event->title, $event->url, $event->affiliation, $event->host, $event->firstname, $event->lastname,
    $event->speaker_title, $event->location, $event->brand, $event->category, $event->type;

  ## no critic (ImplicitNewlines)
  if( $event->event_id ) { ## Performing update
    $self->query( 'update event set updated_at=?,updated_by=?,status=?,
      start_date=?, end_date=?, regclose_date=?, start_time=?, end_time=?,
      title=?, url=?, type_id=?, category_id=?, location_id=?, title_id=?, firstname=?,
      lastname=?, affiliation=?, host=?, precis=?, _search_=? where event_id = ?',
      $now, $event->updated_by, 'active',
      $event->start_date, $event->end_date, $event->regclose_date, $event->start_time, $event->end_time,
      $event->title, $event->url, $event->type_id, $event->category_id, $event->location_id, $event->title_id||0,
      $event->firstname, $event->lastname, $event->affiliation, $event->host, $event->precis,
      $search_string, $event->event_id );
  } else { ## Performing store
    my $id = $self->insert( 'insert ignore into event
      (created_at,created_by,updated_at,updated_by,status,
       start_date, end_date, regclose_date, start_time, end_time,
       title, url, type_id, category_id, location_id, title_id, firstname,
       lastname, affiliation, host, precis, _search_) values 
       (?,?,?,?,?,
        ?,?,?,?,?,
        ?,?,?,?,?,?,?,
        ?,?,?,?,?)',
    'event', 'event_id',
    $now, $event->created_by,  $now, $event->created_by, 'active',
    $event->start_date, $event->end_date, $event->regclose_date, $event->start_time, $event->end_time,
    $event->title, $event->url, $event->type_id, $event->category_id, $event->location_id, $event->title_id||0,
    $event->firstname, $event->lastname, $event->affiliation, $event->host, $event->precis,
    $search_string );
    $event->set_event_id( $id );
  }
  ## use critic
  return $event->event_id;
}

1;
