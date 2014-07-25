package Pagesmith::Authenticate::Ldap::UnixGroups;

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
use Net::LDAP;

use base qw(Pagesmith::Authenticate::Ldap);

use Const::Fast qw(const);
const my $GROUP_INDEX => 3;

sub authenticate {
  my( $self, $username, $pass, $parts ) = @_;
  my $details = $self->SUPER::authenticate( $username, $pass, $parts );
  if( $details->{'ldap_id'} ) {
    my $res = $self->run_cmd( ['groups', $details->{'ldap_id'}] );
    ( my $groups = $res->{'stdout'}[0] ) =~ s{\A.*?:\s+}{}mxs;
    my %groups = map { ($_=>1) } split m{\s+}mxs, $groups;
    $groups{ [getgrgid [getpwnam $details->{'ldap_id'}]->[$GROUP_INDEX]]->[0] }=1;
    push @{$details->{'groups'}}, map { "unix:$_" } sort keys %groups;
  }
  return $details;
}

1;
