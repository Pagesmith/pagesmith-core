package Pagesmith::Action::WhatsMyIP;

## Handles error messages
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

  my $t = $self->twocol->add_entry( 'IP', $self->r->headers_in->get('X-Forwarded-For') );

  my @client_realms = split m{,\s+}mxs, $self->r->headers_in->get('ClientRealm')||q();
  $t->add_entry( 'Realm', $_ ) foreach @client_realms;
  return $self->wrap( q(What's my IP?), $t->render)->ok;
}

1;
