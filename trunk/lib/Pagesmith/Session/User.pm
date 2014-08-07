package Pagesmith::Session::User;

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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Session);

sub new {
  my( $class, $r, $params ) = @_;
  return $class->SUPER::new( $r, {( %{$params||{}}, 'type' => 'User', )} );
}

## Some convenience methods...

sub auth_method {
  my $self = shift;
  return $self->data->{'method'}||q();
}

sub email {
  my $self = shift;
  return $self->data->{'email'} if exists $self->data->{'email'};
  return $self->data->{'id'}    if exists $self->data->{'id'} && $self->data->{'id'} =~ m{@}mxs;
  return;
}

sub access_token {
  my $self = shift;
  return $self->data->{'access_token'};
}

sub refresh_token {
  my $self = shift;
  return $self->data->{'refresh_token'};
}

sub logged_in {
  my $self = shift;
  return unless $self->data;
  return exists $self->data->{'id'};
}

sub username {
  my $self = shift;
  return $self->data->{'id'};
}

sub groups {
  my $self = shift;
  return () unless exists $self->data->{'groups'};
  return @{$self->data->{'groups'}};
}

sub in_group {
  my( $self, $gp ) = @_;
  return 1 if any { $_ eq $gp } $self->groups;
  return 0;
}

sub status {
  my $self = shift;
  return $self->data->{'status'};
}

sub ldap_id {
  my $self = shift;
  return $self->data->{'ldap_id'};
}

sub uid {
  my $self = shift;
  return $self->data->{'uid'};
}

sub ext_id {
  my $self = shift;
  return $self->data->{'ext_id'};
}

sub name {
  my $self = shift;
  return $self->data->{'name'};
}

1;

__END__

Notes
-----

Object should have at a minimum:

 * username    - user email/internal id
 * name        - users' name
 * email       - email address
 * uid         - unique id
 * id          - id

