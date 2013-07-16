package Pagesmith::Action::Das::DSN;

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

  return $self->xml->printf(
    qq(<?xml version="1.0" encoding="UTF-8" ?>\n<?xml-stylesheet type="text/xsl" href="/core/css/das.xsl"?>\n<DASDSN>%s</DASDSN>),
    join q(),
    map { $_->{'dsn_doc'} }
    $self->filtered_sources,
  )->ok;
}


1;
