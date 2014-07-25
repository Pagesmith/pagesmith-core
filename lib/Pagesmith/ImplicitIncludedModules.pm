package Pagesmith::ImplicitIncludedModules;

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

## Not really used - but useful for the boot-strapper to pickup modules
## which we don't necessarily use and won't be automagically installed
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

use DBD::Oracle;
use DBD::mysql;
use Linux::Pid;
use Perl::Tidy;
use Perl::Critic::Bangs;
use Perl::Critic::Itch;
use Perl::Critic::PetPeeves::JTRAMMELL;
use Perl::Critic::Pulp;
use Perl::Critic::Swift;
use Perl::Critic::StricterSubs;
use Perl::Critic::Storable;
use PPI;


1;
