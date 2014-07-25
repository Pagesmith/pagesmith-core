package Pagesmith::ObjectAccessors;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
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

## Base class for auto-creating methods from configuration...!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Thu, 23 Jan 2014
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Object);

## Now we have the standard methods for this sub-class of objects which we want to define
## These are added to the base class!!
sub init {
  my( $self, $hashref, $partial ) = @_;
  $self->{'obj'} = {%{$hashref}};
  $self->flag_as_partial if defined $partial && $partial;
  return;
}

sub type {
#@param ($self)
#@return (String);
## Gets the type of object (basically anything after the last ::)
  my $self = shift;
  my ( $type ) = (ref $self) =~ m{([^:]+)\Z}mxsg;
  return $type;
}

sub get_created_at {
  my $self = shift;
  return $self->{'obj'}{'created_at'};
}

sub set_created_at {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_at'} = $value;
  return $self;
}

sub get_created_by_id {
  my $self = shift;
  return $self->{'obj'}{'created_by_id'}||0;
}

sub set_created_by_id {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_by_id'} = $value;
  return $self;
}

sub get_created_by {
  my $self = shift;
  return $self->{'obj'}{'created_by'}||0;
}

sub set_created_by {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_by'} = $value;
  return $self;
}

sub get_created_ip {
  my $self = shift;
  return $self->{'obj'}{'created_ip'};
}

sub set_created_ip {
  my( $self, $value ) = @_;
  $self->{'obj'}{'ip'} = $value;
  return $self;
}

sub get_created_useragent {
  my $self = shift;
  return $self->{'obj'}{'created_useragent'};
}

sub set_created_useragent {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_useragent'} = $value;
  return $self;
}

sub get_updated_at {
  my $self = shift;
  return $self->{'obj'}{'updated_at'};
}

sub set_updated_at {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_at'} = $value;
  return $self;
}

sub get_updated_by {
  my $self = shift;
  return $self->{'obj'}{'updated_by'}||0;
}

sub set_updated_by {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_by'} = $value;
  return $self;
}

sub get_updated_by_id {
  my $self = shift;
  return $self->{'obj'}{'updated_by_id'}||0;
}

sub set_updated_by_id {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_by_id'} = $value;
  return $self;
}

sub get_updated_ip {
  my $self = shift;
  return $self->{'obj'}{'updated_ip'};
}

sub set_updated_ip {
  my( $self, $value ) = @_;
  $self->{'obj'}{'ip'} = $value;
  return $self;
}

sub get_updated_useragent {
  my $self = shift;
  return $self->{'obj'}{'updated_useragent'};
}

sub set_updated_useragent {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_useragent'} = $value;
  return $self;
}

sub store {
  my $self = shift;
  return $self->adaptor->store( $self );
}

sub get_other_adaptor {
  my( $self, $type ) = @_;
  return $self->adaptor->get_other_adaptor( $type );
}

sub set_attribute {
  my ( $self, $name, $value ) = @_;
  $self->{'attributes'}||={};
  $self->{'attributes'}{$name} = $value;
  return $self;
}

sub get_attribute {
  my ( $self, $name, $default ) = @_;
  return exists $self->{'attributes'}{$name} ? $self->{'attributes'}{$name} : $default;
}

sub get_attribute_names {
  my $self = shift;
  $self->{'attributes'}||={};
  return keys %{$self->{'attributes'}};
}

sub unset_attribute {
  my( $self, $name ) = @_;
  $self->{'attributes'}||={};
  return unless exists $self->{'attributes'}{$name};
  return delete $self->{'attributes'}{$name};
}

sub reset_attributes {
  my $self = shift;
  $self->{'attributes'} = {};
  return $self;
}

1;
