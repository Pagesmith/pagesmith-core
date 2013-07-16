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

my @T = $self->filtered_sources;
  return $self->xml->printf(
    '<SOURCES>%s</SOURCES>',
    join q(),
    map { $_->{'sources_doc'} }
    $self->filtered_sources,
  )->ok;
}

1;
