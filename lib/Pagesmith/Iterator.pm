package Pagesmith::Iterator;

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

## Base class for other web-adaptors...
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

## Supplies wrapper functions for DBI

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

sub new {
  my ( $class, $sth ) = @_;
  my $self = { 'sth' => $sth };
  bless $self, $class;
  return $self;
}

sub get {
  my $self = shift;
  my $row = $self->{'sth'}->fetchrow_hashref;
  return $row if $row;
  $self->{'sth'}->finish;
  return;
}

sub finish {
  my $self = shift;
  return unless $self->{'sth'};
  $self->{'sth'}->finish;
  return;
}

1;
