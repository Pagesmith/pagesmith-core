package Pagesmith::Object::GenericFile;

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

##
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

use base qw(Pagesmith::Object::Generic);

sub new {
  my($class,$adaptor,$object_data) = @_;
     $object_data    ||= {};
  my $self = $class->SUPER::new( $adaptor, $object_data );
  $self->{'mime_type'} = $object_data->{'mime_type'}||$adaptor->mime_type; ## Copy mime_type from object data!
  $self->{'code'}      = $object_data->{'code'};
  $self->{'type'}      = $object_data->{'type'};
  $self->{'sort_order'} = [ split m{\t}mxs, $object_data->{'sort_order'} ] if exists $object_data->{'sort_order'};
  return $self;
}

sub mime_type {
  my $self = shift;
  return $self->{'mime_type'};
}

sub set_mime_type {
  my ($self,$val) = @_;
  $self->{'mime_type'} = $val;
  return $self;
}

## no critic (Autoloading)
sub AUTOLOAD {
  my $self = shift;
  return $self;
}
## use critic

sub code {
  my $self = shift;
  return $self->{'code'};
}

sub sort_order {
  my $self = shift;
  return $self->{'sort_order'};
}

sub set_code {
  my ($self,$val) = @_;
  $self->{'code'} = $val;
  return $self;
}

sub set_sort_order {
  my ($self,@order) = @_;
  $self->{'sort_order'} = [@order];
  return $self;
}

1;
