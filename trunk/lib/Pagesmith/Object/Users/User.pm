package Pagesmith::Object::Users::User;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2014 Genome Research Ltd.
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

## Object representing a user in the user database...
## Author         : js5
## Maintainer     : js5
## Created        : 2011-06-01
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
  my($class,$adaptor,$user_data) = @_;
     $user_data    ||= {};
  my $self    = {
    '_adpt'        => $adaptor,
    'id'           => $user_data->{'id'},
    'code'         => $user_data->{'email'},
    'password'     => $user_data->{'password'},
    'name'         => $user_data->{'name'},
    'institute'    => $user_data->{'institute'},
    'grouptype'    => $user_data->{'grouptype'},
    'status'       => $user_data->{'status'} || 'active',
    'status_id'    => $user_data->{'status_id'} || 0,
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

sub email {
  my $self = shift;
  return $self->{'code'};
}

sub set_email {
  my( $self,$code ) = @_;
  $self->{'code'} = $code;
  return $self;
}

sub password {
  my $self = shift;
  return $self->{'password'};
}

sub set_password {
  my( $self,$password ) = @_;
  $self->{'password'} = $password;
  return $self;
}

sub update_password {
  my ($self,$password) = @_;
  $self->set_password($password);
  return $self->adaptor->change_member_password( $self );
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

sub institute {
  my $self = shift;
  return $self->{'institute'};
}

sub set_institute {
  my( $self,$institute ) = @_;
  $self->{'institute'} = $institute;
  return $self;
}

sub update_institute {
  my $self = shift;
  return $self->adaptor->change_member_institute($self);
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

sub status_id {
  my $self = shift;
  return $self->{'status_id'};
}

sub set_status_id {
  my( $self,$status_id ) = @_;
  $self->{'status_id'} = $status_id;
  return $self;
}

sub update_status_id {
  my $self = shift;
  return $self->adaptor->change_member_status($self);
}

## Membership functions...
sub get_groups {
  my $self = shift;
  return $self->adaptor->get_groups_by_member( $self );
}

sub add_to_group {
  my( $self, $group, $status ) = @_;
  return $self->adaptor->add_member_to_group( $self, $group, $status );
}

sub change_group_status {
  my( $self, $user, $status ) = @_;
  return $self->adaptor->change_member_status_in_group( $user, $self, $status );
}

sub remove_from_group {
  my( $self, $group ) = @_;
  return $self->adaptor->remove_member_from_group( $self, $group );
}

sub has_member { # untested.
  my( $self, $user, $group ) = @_;
  return $self->adaptor->is_member_in_group( $self, $user, $group );
}

## Store functions...
sub store {
  my $self = shift;
  my $id = $self->adaptor->store_member($self);
  $self->set_id($id) if ($id);
  return $id;
}

sub objdata {
  my $self = shift;

  my @groups = @{$self->adaptor->get_groups_by_member($self)};
  my @group_string;
  if (@groups) {
    push @group_string, $_->{'code'} foreach @groups;
  }
  return {(
    'id'        => $self->{'id'},
    'name'      => $self->name,
    'institute' => $self->institute,
    'groups'    => [@group_string],
    'email'     => $self->{'code'},
    'status'    => $self->status,
    'password'  => $self->{'password'},
    'grouptype' => $self->{'grouptype'},
    'status_id' => $self->{'status_id'},
        )};

}
1;
