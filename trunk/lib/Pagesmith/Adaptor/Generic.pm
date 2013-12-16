package Pagesmith::Adaptor::Generic;

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
use feature qw(switch);

use base qw(Pagesmith::Adaptor);

use MIME::Base64 qw(decode_base64 encode_base64);

use Pagesmith::Object::Generic;

sub connection_pars {
  return 'objectstore';
}

sub get_sort_order_value {
  my( $self, $generic_obj ) = @_;
  my $method = 'get_'.$self->{'code'};
  my @values;
  foreach ( @{ $self->{'sort_order'} } ) {
    my $o_method = 'get_'.$_;
    my $q = $generic_obj->$o_method;
    push @values, defined $q ? $q : q(-);
  }
  return join( "\t", @values) || q(--);
}

sub sort_order {
  my $self = shift;
  return @{ $self->{'sort_order'}||[] };
}

sub set_sort_order {
  my( $self, @attributes ) = @_;
  $self->{'sort_order'} = \@attributes;
  return $self;
}

sub get_code_value {
  my( $self, $generic_obj ) = @_;
  my $method = 'get_'.($self->{'code'}||'code');
  return $generic_obj->$method || q(--);
}

sub set_code {
  my( $self, $code ) = @_;
  $self->{'code'} = $code;
  return $self;
}

sub set_type {
  my( $self, $type ) = @_;
  $self->{'type'} = $type;
  return $self;
}

sub type {
  my $self = shift;
  return $self->{'type'};
}

sub create {

#@param (self)
#@param (hashref)? Optional hashref of attributes
#@return (Pagesmith::Object::Generic)
## Create a new generic object
  my( $self, @pars ) = @_;
  return Pagesmith::Object::Generic->new( $self, @pars );
}

sub set_table_name {
  my( $self, $value ) = @_;
  $value ||= q();
  $value =~ s{\W}{}mxsg;
  $self->{'table_name'} = $value;
  return $self;
}

sub table_name {
  my $self = shift;
  return $self->{'table_name'} || 'generic';
}

sub get_id {
#@param (self)
#@param (string) URL of page
#@return (Pagesmith::Object::Generic[])
## Return an array of generic objects for the given page
  my ( $self, $id ) = @_;
  ##no critic (ImplicitNewlines)
  my $hashref = $self->row_hash(
    'select code, created_at, created_by, updated_at, updated_by, ip, useragent, objdata, state
       from '.$self->table_name.'
      where type = ? and id=?',
    $self->type, $id,
  );
  return unless $hashref;

## Decode the DB safe version of the object data!
  $hashref->{'objdata'} = $self->json_decode( decode_base64( $hashref->{'objdata'} ) );
##use critic (ImplicitNewlines)
  return $self->create( { 'type' => $self->type, 'id' => $id, %{$hashref} } );
}

sub parse_filter {
  my ( $self, @filter ) = @_;

  my $extra = q();
  my @params = ($self->type);

  if( @filter && ref $filter[0] eq 'ARRAY' ) {
    my $restrictions = shift @filter;
    foreach my $filter ( @{$restrictions} ) {
      my ( $column, $type, @values ) = split m{\s+}mxs, $filter;
      given( $type ) {
        when(  'after' ) {
          $extra .= sprintf ' and %s >= ?', $column;
          push @params, $values[0];
        }
        when( 'before' ) {
          $extra .= sprintf ' and %s <= ?', $column;
          push @params, $values[0];
        }
        when( 'in' ) {
          $extra .= sprintf ' and %s in (%s)', $column, join q(,), map { q(?) } @values;
          push @params, @values;
        }
        when( 'notin' ) {
          $extra .= sprintf ' and %s not in (%s)', $column, join q(,), map { q(?) } @values;
          push @params, @values;
        }
        when( 'like' ) {
          $extra .= sprintf ' and %s like ?', $column;
          push @params, "%$values[0]%";
        }
        when( 'notlike' ) {
          $extra .= sprintf ' and %s not like ?', $column;
          push @params, "%$values[0]%";
        }
        when( 'not' ) {
          $extra .= sprintf ' and %s != ?', $column;
          push @params, $values[0];
        }
        default {
          $extra .= sprintf ' and %s = ?', $column;
          push @params, $values[0];
        }
      }
    }
  }
  if( @filter ) {
    my $flag = 0;
    if( $filter[0] eq q(!) ) {
      $flag = 1;
      shift @filter;
    }
    my $filter_string = join "\t", @filter;
    my @Q = $self->sort_order;
    if( @filter == @Q ) {
      $extra = $flag ? ' and sort_order !=?'        : ' and sort_order = ?';
      push @params, $filter_string;
    } else {
      $extra = $flag ? ' and sort_order not like ?' : ' and sort_order like ?';
      push @params, $filter_string."\t%";
    }
  }
  return ($extra,@params);
}

sub get_all {
  my ( $self, @filter ) = @_;
  my ($extra,@params) = $self->parse_filter( @filter );
  ##no critic (ImplicitNewlines)
  my $array = $self->all_hash(
    'select type, id, code, created_at, created_by, updated_at, updated_by, ip, useragent, objdata, state
       from '.$self->table_name.'
      where type = ?'.$extra.'
      order by sort_order',
    @params,
  );

## Decode the DB safe version of the object data!
  my @ret;
  foreach my $hashref ( @{$array} ) {
    $hashref->{'objdata'} = $self->json_decode( decode_base64( $hashref->{'objdata'} ) );
##use critic (ImplicitNewlines)
    push @ret, $self->create( $hashref );
  }
  return \@ret;
}

sub get {
#@param (self)
#@param (string) URL of page
#@return (Pagesmith::Object::Generic[])
## Return an array of generic objects for the given page
  my ( $self, $code ) = @_;
  ##no critic (ImplicitNewlines)
  my $hashref = $self->row_hash(
    'select id,created_at, created_by, updated_at, updated_by, ip, useragent, objdata, state
       from '.$self->table_name.'
      where type = ? and code=?',
    $self->type, $code,
  );
  return unless $hashref;

## Decode the DB safe version of the object data!
  $hashref->{'objdata'} = $self->json_decode( decode_base64( $hashref->{'objdata'} ) );
##use critic (ImplicitNewlines)
  return $self->create( { 'type' => $self->type, 'code' => $code, %{$hashref} } );
}

sub json_safer_encode {
  my( $self, $struct ) = @_;
  my $encoded = eval { $self->json_encode( $struct ); };
  return $encoded if $encoded;
  if( 'HASH' eq ref $struct ) {
    return sprintf '{%s}', join q(,),
      map { sprintf '"%s":%s', $_, $self->json_safer_encode( $struct->{$_} ) } keys %{$struct};
  } elsif( 'ARRAY' eq ref $struct ) {
    return sprintf '[%s]', join q(,),
      map { $self->json_safer_encode( $struct->{$_} ) } @{$struct};
  } else {
    my $value = eval { $self->json_encode( $struct ); };
    return $value if $value;
    $struct =~ s{[^ -~]}{ }mxsg;
    return $self->json_encode( $struct );
  }
}

sub store {
#@param (self)
#@param (Pagesmith::Object::Generic) object to store
#@return (boolean) true if insert OK
## Store the generic object in the database
  my ( $self, $generic_obj ) = @_;
  my $json_string = eval { $self->json_encode( $generic_obj->objdata ); };
  unless( $json_string ) {
    ## We can not encode the string... AROOGA AROOGA....
    ## What do we do now!!!
    $json_string = $self->json_safer_encode( $generic_obj->objdata );
    return 0 unless $json_string;
  }
  my $obj_data = encode_base64( $json_string );
  my $type = $generic_obj->type || $self->{'type'};

  $generic_obj->set_ip_and_useragent unless $generic_obj->ip;
  $generic_obj->set_state( 'new' )                  unless defined $generic_obj->state;
  if( $generic_obj->id ) {
    $generic_obj->set_updated_by( $self->user );
    $generic_obj->set_updated_at( $generic_obj->now );
  ##no critic (ImplicitNewlines)
    return $self->query(
     'update '.$self->table_name.'
         set code = ?, sort_order = ?, updated_at = ?, updated_by = ?, objdata = ?, state = ?
       where type = ? and id = ?',
      $self->get_code_value( $generic_obj ),
      $self->get_sort_order_value( $generic_obj ),
      $generic_obj->updated_at, $generic_obj->updated_by, $obj_data, $generic_obj->state,
      $type, $generic_obj->id,
    );
  ##use critic
  }
  $generic_obj->set_created_by( $self->user );
  $generic_obj->set_created_at( $generic_obj->now );
  ##no critic (ImplicitNewlines)
  my $sql = 'insert ignore into '.$self->table_name.'
                    (code,sort_order, created_at,  created_by, ip,      useragent,
                     type,        objdata, state)
                    values( ?,?,?,          ?,          ?,    ?,
                            ?,          ?,          ?
                    )';
  $generic_obj->set_id( $self->insert( $sql, $self->table_name, 'id',
    $self->get_code_value( $generic_obj ),
    $self->get_sort_order_value( $generic_obj ),
    $generic_obj->created_at, $generic_obj->created_by, $generic_obj->ip,      $generic_obj->useragent,
    $type,       $obj_data , $generic_obj->state,
  ));
  ##use critic (ImplicitNewlines)
  return $generic_obj->id ? 1 : 0;
}

1;
