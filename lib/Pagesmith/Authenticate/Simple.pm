package Pagesmith::Authenticate::Simple;

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

## Authenticate using Ldap
## Author         : mw6
## Maintainer     : mw6
## Created        : 2010-11-05
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use List::MoreUtils qw(all);

use base qw(Pagesmith::Authenticate);

sub new {
  my( $class, $conf ) = @_;
  my $self = {
    'users'         => $conf->{'users'},
    'encrypted'     => $conf->{'encrypted'},
    'groups'        => exists $conf->{'groups'} ? $conf->{'groups'} : {},
  };
  bless $self, $class;
  return $self;
}

sub users {
  my $self = shift;
  return $self->{'users'};
}

sub encrypted {
  my $self = shift;
  return $self->{'encrypted'};
}

sub authenticate {
  my( $self, $username, $pass, $parts ) = @_;
  return {} unless exists $self->users->{$username};
  my( $password, $name ) = @{ $self->users->{$username} };
  if( $self->encrypted ) {
    $pass = crypt $pass, $password;
  }
  return {} unless $password eq $pass;
  return {(
    'id'      => $username,
    'name'    => $name,
    'groups'  => $self->user_groups( $username ),
  )};
}

1;
