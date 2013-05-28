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

  return $self->wrap( q(What's my IP?),
    $self->twocol->add_entry( 'IP', $self->r->headers_in->get('X-Forwarded-For') )->render,
  )->ok;
}

1;
