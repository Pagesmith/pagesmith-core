package Pagesmith::Adaptor::Generic;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

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

use base qw(Pagesmith::BaseAdaptor);

use MIME::Base64 qw(decode_base64 encode_base64);
use English qw(-no_match_vars $PROGRAM_NAME);
use Sys::Hostname qw(hostname);
use Socket qw(inet_ntoa);
use Const::Fast qw(const);

use Pagesmith::Object::Generic;

const my $FILTER_MAP => {
  'after'   => q(>=),
  'before'  => q(<=),
  'in'      => 'in',
  'notin'   => 'not in',
  'like'    => 'like',
  'notlike' => 'not like',
  'no'      => q(!=),
};


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
        $extra .= sprintf ' and %s %s ',
        $column,
        exists $FILTER_MAP->{$type} ? $FILTER_MAP->{$type} : q(=);
      if( $type eq 'in' || $type eq 'notin' ) {
        $extra .= sprintf '(%s)', join q(,), map { q(?) } @values;
        push @params, @values;
      } else {
        $extra .= q(?);
        push @params, $type eq 'like' || $type eq 'notlike'
                    ? "%$values[0]%"
                    : $values[0];
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
  $generic_obj->set_status( 'new' )                  unless defined $generic_obj->status;
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
      $generic_obj->updated_at, $generic_obj->updated_by, $obj_data, $generic_obj->status,
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
    $type,       $obj_data , $generic_obj->status,
  ));
  ##use critic (ImplicitNewlines)
  return $generic_obj->id ? 1 : 0;
}

sub set_ip_and_useragent {
  my( $self, $object_to_update ) = @_;
  if( exists $self->{'_r'} && $self->r ) {
    $object_to_update->set_ip(
      $self->r->headers_in->{'X-Forwarded-For'} ||
      $self->remote_ip,
    );
    $object_to_update->set_useragent( $self->r->headers_in->{'User-Agent'} || q(--) );
  } else {
    my $host = hostname() || 'localhost';
    $object_to_update->set_ip( inet_ntoa( scalar gethostbyname $host ) );
    $object_to_update->set_useragent( "$ENV{q(SHELL)} $PROGRAM_NAME" );
  }
  return $self;
}

1;
