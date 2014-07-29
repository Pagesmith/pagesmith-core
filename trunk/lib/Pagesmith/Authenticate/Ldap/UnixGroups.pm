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

use base qw(Pagesmith::Authenticate::Ldap);

sub authenticate {
  my( $self, $username, $pass, $parts ) = @_;
  my $details = $self->SUPER::authenticate( $username, $pass, $parts );
  ## No ldap user ...!
  return $details unless $details->{'ldap_id'};

  ## Get additional group information!
  (my $group_url = $self->base ) =~ s{people}{group}mxs;
  my $result = $self->ldap->search(
    'attrs'  => [qw(cn)],
    'base'   => $group_url,
    'filter' => sprintf 'member=%s=%s,%s', $self->id, $details->{'ldap_id'}, $self->base,
  );

  ## Request fails... can't get groups!
  return $details unless $result;

  push @{$details->{'groups'}},
    sort
    map { q(unix:).$_->get_value('cn') }
    $result->entries;
  return $details;
}

1;
