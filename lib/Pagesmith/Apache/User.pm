package Pagesmith::Apache::User;

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
