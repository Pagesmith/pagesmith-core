package Pagesmith::Action::Delay;

## Action to handle delayed links (useful for testing purposes!)
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

use Time::HiRes qw(sleep);

sub run {
  my $self  = shift;
  $self->init_events;
  my $sleep = $self->next_path_info;
  $self->push_event( 'Get path info' );
  my $url   = join q(/), q(), $self->path_info;
  $self->push_event( 'Generated URL' );
  sleep $sleep;
  $self->push_event( 'Slept' );
  $self->dump_events;
  return $self->redirect($url);
}

1;
