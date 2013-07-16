package Pagesmith::Action::Das::Sources;

## Monitorus proxy!
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-13
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action::Das);

sub run {
  my $self = shift;
  $self->r->headers_out->set( 'X-Das-Capabilities', 'sources/1.0; dsn/1.0' );
  return $self->sources_markup( $self->filtered_sources );
}

1;
