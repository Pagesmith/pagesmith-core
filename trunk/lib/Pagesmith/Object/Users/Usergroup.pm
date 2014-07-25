package Pagesmith::Object::Users::Usergroup;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2014 Genome Research Ltd.
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

use base qw(Pagesmith::BaseObject);

sub new {
  my($class,$adaptor,$usergroup_data) = @_;
     $usergroup_data    ||= {};
  my $self    = {
    'adaptor'      => $adaptor,
    'code'         => $usergroup_data->{'code'},
    'name'         => $usergroup_data->{'name'},
    'description'  => $usergroup_data->{'description'},
    'grouptype'    => $usergroup_data->{'grouptype'},
    'status'       => $usergroup_data->{'status'}||'active',
  };
  bless $self, $class;
  return $self;
}

sub type {
  my $self = shift;
  return $self->{'grouptype'};
}

sub set_type {
  my( $self, $type ) = @_;
  $self->{'grouptype'} = $type;
  return $self;
}

sub code {
  my $self = shift;
  return $self->{'code'};
}

sub set_code {
  my( $self,$code ) = @_;
  $self->{'code'} = $code;
  return $self;
}

sub name {
  my $self = shift;
  return $self->{'name'};
}

sub set_name {
  my( $self,$name ) = @_;
  $self->{'name'} = $name;
  return $self;
}

sub description {
  my $self = shift;
  return $self->{'description'};
}

sub set_description {
  my( $self,$description ) = @_;
  $self->{'description'} = $description;
  return $self;
}

sub status {
  my $self = shift;
  return $self->{'status'};
}

sub set_status {
  my( $self,$status ) = @_;
  $self->{'status'} = $status;
  return $self;
}

sub store {
  my $self = shift;
  return $self->{'adaptor'}->store_group($self);
}
1;
