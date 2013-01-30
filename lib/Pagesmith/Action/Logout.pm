package Pagesmith::Action::Logout;

## Logout action
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

use Pagesmith::Session::User;

sub run {
  my $self = shift;
## Clear the cookies!
## Check the user is "setup" - if so clear the "user sesssion"

  my $user_session = Pagesmith::Session::User->new($self->r);

  $user_session->clear_cookie->session_cache->unset if $user_session->read_cookie;

  return $self->redirect( $self->r->headers_in->{'Referer'} || $self->base_url.q(/) );
}

1;
