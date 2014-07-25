package Pagesmith::Apache::User;

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

## Component
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

use Apache2::Const qw(OK DECLINED);
use Apache2::RequestUtil;
use Pagesmith::Session::User;

sub fixup_handler {
  my $r = shift;
  my $user_session = Pagesmith::Session::User->new( $r );
  if( $user_session->read_cookie ) {
    $r->notes->set(  'user_session_id',  $user_session->uuid );
    if( 0 && $r->is_initial_req ) { ## We can enable this to put username into headers to be picked up by ZXTM...
      $user_session->fetch;
      $r->headers_out->set( 'Pagesmith_User_Name', $user_session->username );
    }
  } else {
    $r->notes->set(  'user_session_id',  0 );
  }
  $r->pnotes( 'user_session'    => $user_session );  ## Store the uses session as a pnote!
  return OK;
}

sub log_handler {
  my $r = shift;

  if( $r->notes->get( 'user_session_id' ) ) {
    my $us = $r->pnotes( 'user_session' );
    if( $us->fetch ) {
      $r->notes->set('user_name', $us->username);
    } else {
      $r->notes->set('user_name', q(-) );
    }
  }
  return DECLINED;
}
1;
