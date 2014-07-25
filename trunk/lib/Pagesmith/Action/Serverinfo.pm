package Pagesmith::Action::Serverinfo;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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

## Dumps the headers...
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

use base qw(Pagesmith::Action);

sub run {
  my $self = shift;
  my $ret = {};
  if( open my $fh, q(-|), q(uptime) ) {
    my $uptime = <$fh>;
    close $fh; ## no critic (RequireChecked)
    if( $uptime =~ m{load\s+average:\s*(\d+[.]\d+),\s*(\d+[.]\d+),\s*(\d+[.]\d+)}mxs ) {
      $ret->{'load_1'}  = $1;
      $ret->{'load_5'}  = $2;
      $ret->{'load_15'} = $3;
    }
  }
  if( open my $fh, q(-|), q(cat), q(/proc/meminfo) ) {
    my @meminfo = <$fh>;
    close $fh; ## no critic (RequireChecked)
    foreach( @meminfo ) {
      chomp;
      my( $k, $v ) = split m{:\s*}mxs, $_, 2;
      $ret->{$k} = $v;
    }
  }
  return $self->json_print( $ret );
}

1;
