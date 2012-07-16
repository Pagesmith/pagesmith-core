package Pagesmith::Component::User;

##
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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Component);
use HTML::Entities qw(encode_entities);

sub execute {
  my $self = shift;
  my @realms = $self->pars;
# No restriction so return!
  my $login_realm = 1;
  if( @realms ) {
    my $client_realms = $self->r->headers_in->get('ClientRealm');
    if( defined $client_realms ) {
      my %realms = map { ( $_, 1 ) } @realms;
      my @user_realms = split m{[,\s]+}mxs, $client_realms;
      $login_realm = 0 unless any { $realms{$_} } @user_realms;
    } else {
      $login_realm = 0;
    }
  }

  ## Initialise User session object!
  my $user_session = $self->page->user;
  if( $user_session && $user_session->fetch ) {
    return sprintf q(<div id="user">%s logged in <a href="/action/logout"><img id="logout" src="/core/gfx/blank.gif" alt="Logout" /></a></div>),
      encode_entities( $user_session->name );
  }
  return q() unless $login_realm;
  return q(<div id="user"><a href="/login"><img id="login" src="/core/gfx/blank.gif" alt="Login" /></a></div>);
}

1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

