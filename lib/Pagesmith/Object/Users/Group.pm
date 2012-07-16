package Pagesmith::Object::Users::Group;

## Object representing a group in the user database...
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

use base qw(Pagesmith::Object);

sub new {
  my($class,$adaptor,$usergroup_data) = @_;
     $usergroup_data    ||= {};
  my $self    = {
    'adaptor'      => $adaptor,
    'id'           => $usergroup_data->{'id'}||0,
    'code'         => $usergroup_data->{'code'},
    'name'         => $usergroup_data->{'name'},
    'description'  => $usergroup_data->{'description'},
    'grouptype'    => $usergroup_data->{'grouptype'},
    'status'       => $usergroup_data->{'status'}||'active',
  };
  bless $self, $class;
  return $self;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub set_id {
  my( $self,$status ) = @_;
  $self->{'id'} = $status;
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

## Membership functions...

## Get current members in group...

sub get_member_list {
  my $self = shift;
  return $self->adaptor->get_members_by_group( $self );
}

## Add, remove, change status of member in a group...
sub add_member {
  my( $self, $user, $status ) = @_;
  return $self->adaptor->add_member_to_group( $user, $self, $status );
}

sub change_member_status {
  my( $self, $user, $status ) = @_;
  return $self->adaptor->change_member_status_in_group( $user, $self, $status );
}

sub remove_member {
  my( $self, $user ) = @_;
  return $self->adaptor->remove_member_from_group( $user, $self );
}

## Check if members is in group (and return status)...
sub has_active_member {
  my( $self, $user ) = @_;
  my $status = $self->adaptor->get_member_group_status( $user, $self );
  return unless $status;
  return $status eq 'active';
}

sub get_member_status {
  my( $self, $user ) = @_;
  return $self->adaptor->get_member_group_status( $user, $self );
}

## Create/update a group in the database!
sub store {
  my $self = shift;
  return $self->adaptor->store_group($self);
}
1;
