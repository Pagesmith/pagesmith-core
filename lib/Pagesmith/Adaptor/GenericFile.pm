package Pagesmith::Adaptor::GenericFile;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

use base qw(Pagesmith::Adaptor::Generic);

use MIME::Base64 qw(decode_base64 encode_base64);

use Pagesmith::Object::GenericFile;

sub set_mime_type {
  my( $self, $type ) = @_;
  $self->{'mime_type'} = $type;
  return $self;
}

sub mime_type {
  my $self = shift;
  return $self->{'mime_type'};
}

sub create {
#@param (self)
#@param (hashref)? Optional hashref of attributes
#@return (Pagesmith::Object::Generic)
## Create a new generic object
  my( $self, @pars ) = @_;
  return Pagesmith::Object::GenericFile->new( $self, @pars );
}

sub table_name {
  my $self = shift;
  return $self->{'table_name'} || 'genfile';
}

sub get_id {
#@param (self)
#@param (string) id
#@return (Pagesmith::Object::GenericFile[])
## Return an array of generic objects for the given page
  my ( $self, $id ) = @_;
  ##no critic (ImplicitNewlines)
  my $hashref = $self->row_hash(
    'select code, mime_type, created_at, created_by, updated_at, updated_by, ip, useragent, objdata, state
       from '.$self->table_name.'
      where type = ? and genfile_id=?',
    $self->type, $id,
  );
  return unless $hashref;
## Decode the DB safe version of the object data!
##use critic (ImplicitNewlines)
  return $self->create( { 'type' => $self->type, 'id' => $id, %{$hashref} } );
}

sub get_all {
  my ( $self, @filter ) = @_;
  my ($extra,@params) = $self->parse_filter( @filter );
  ##no critic (ImplicitNewlines)
  my $array = $self->all_hash(
    'select type, genfile_id, code, mime_type, created_at, created_by, updated_at, updated_by, ip, useragent, objdata, state, sort_order
       from '.$self->table_name.'
      where type = ?'.$extra.'
      order by sort_order',
    @params,
  );
  ## use critic

## Decode the DB safe version of the object data!
  my @ret = map { $self->create( $_ ) } @{$array};
  return \@ret;
}

sub get {
#@param (self)
#@param (string) URL of page
#@return (Pagesmith::Object::GenericFile[])
## Return an array of generic objects for the given page
  my ( $self, $code ) = @_;
  ##no critic (ImplicitNewlines)
  my $hashref = $self->row_hash(
    'select genfile_id, mime_type, created_at, created_by, updated_at, updated_by, ip, useragent, objdata, state, sort_order
       from '.$self->table_name.'
      where type = ? and code=?',
    $self->type, $code,
  );
  return unless $hashref;

## Decode the DB safe version of the object data!
##use critic (ImplicitNewlines)
  return $self->create( { 'type' => $self->type, 'code' => $code, %{$hashref} } );
}

sub store {
#@param (self)
#@param (Pagesmith::Object::GenericFile) object to store
#@return (boolean) true if insert OK
## Store the generic object in the database
  my ( $self, $generic_obj ) = @_;

  my $type = $generic_obj->type || $self->{'type'};
  my $mime_type = $generic_obj->mime_type || $self->{'mime_type'};
  $generic_obj->set_ip_and_useragent unless $generic_obj->ip;
  $generic_obj->set_status( 'new' )                  unless defined $generic_obj->status;
  if( $generic_obj->id ) {
    $generic_obj->set_updated_by( $self->user );
    $generic_obj->set_updated_at( $generic_obj->now );
  ##no critic (ImplicitNewlines)
    return $self->query(
     'update '.$self->table_name.'
         set code = ?, sort_order = ?, updated_at = ?, updated_by = ?, objdata = ?, state = ?, mime_type = ?
       where type = ? and id = ?',
      $self->get_code_value( $generic_obj ),
      $self->get_sort_order_value( $generic_obj ),
      $generic_obj->updated_at, $generic_obj->updated_by, $generic_obj->objdata, $generic_obj->status, $mime_type,
      $type, $generic_obj->id,
    );
  ##use critic
  }
  $generic_obj->set_created_by( $self->user );
  $generic_obj->set_created_at( $generic_obj->now );
  ##no critic (ImplicitNewlines)
  my $sql = 'insert ignore into '.$self->table_name.'
                    (code,    sort_order, created_at,  created_by,
                     ip,      useragent,  mime_type,   type,
                     objdata, state)
                    values( ?,?,?,?,
                            ?,?,?,?,
                            ?,?
                    )';
  $generic_obj->set_id( $self->insert( $sql, $self->table_name, 'id',
    $self->get_code_value( $generic_obj ),
    $self->get_sort_order_value( $generic_obj ),
    $generic_obj->created_at, $generic_obj->created_by, $generic_obj->ip,      $generic_obj->useragent, $mime_type,
    $type, $generic_obj->objdata , $generic_obj->status,
  ));
  ##use critic (ImplicitNewlines)
  return $generic_obj->id ? 1 : 0;
}

sub get_sort_order_value {
  my( $self, $generic_obj ) = @_;
  return $generic_obj->{'code'} unless exists $generic_obj->{'sort_order'};
  return $generic_obj->{'code'} unless 'ARRAY' eq ref $generic_obj->{'sort_order'};
  return $generic_obj->{'code'} unless @{$generic_obj->{'sort_order'}};
  return join "\t", @{$generic_obj->{'sort_order'}};
}

sub get_code_value {
  my( $self, $generic_obj ) = @_;
  return $generic_obj->{'code'};
}

1;
