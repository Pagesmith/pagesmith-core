package Pagesmith::Adaptor::DbInc;

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

## Adaptor for comments database
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

use base qw(Pagesmith::BaseAdaptor);

use Pagesmith::ConfigHash qw(is_developer);

sub connection_pars {
  return 'objectstore';
}

sub get_message {
  my( $self, $code, $realms ) = @_;
  $realms = q() unless $realms;
  my $res = $self->row_hash( 'select content,status from message where code = ?', $code );
  return unless defined $res;
  return $res->{'status'} eq 'inactive'                          ? q()
       : $res->{'status'} eq 'active' || is_developer( $realms ) ? $res->{'content'}
       :                                                           q()
       ;
  return q();
}

sub set_message {
  my( $self, $username, $code, $body, $status ) = @_;
  return;
}
1;
