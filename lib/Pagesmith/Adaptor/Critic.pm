package Pagesmith::Adaptor::Critic;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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

## Adaptor to retrieve references from pubmed or the database
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
# no warnings qw(uninitialized)

use version qw(qv); our $VERSION = qv('0.1.0');
use utf8;

use base qw(Pagesmith::BaseAdaptor);

sub connection_pars {
  return ( 'dbi:mysql:critic:web-vm-db-dev:3302', 'critic_rw', 'Cr171Qz' );
}

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless $self, $class;
  return $self;
}

1;
