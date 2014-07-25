package Pagesmith::Authenticate;

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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Support);

sub new {
  my( $class, $conf ) = @_;
  return;
}

sub groups {
  my $self = shift;
  return keys %{ $self->{'groups'} };
}

sub group_members {
  my( $self, $gp ) = @_;
  return @{ $self->{'groups'}{$gp} };
}

sub user_groups {
  my( $self, $user_id ) = @_;
  my @groups;
  foreach my $gp ( $self->groups ) {
    my @members = $self->group_members( $gp );
    push @groups, $gp if !@members || any { $_ eq $user_id } @members;
  }
  return \@groups;
}

1;
