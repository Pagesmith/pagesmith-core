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
use Const::Fast qw(const);
const my $VALID_REQUEST => 200;

sub run {
  my $self = shift;
  $self->r->headers_out->set( 'X-Das-Capabilities', 'sources/1.0; dsn/1.0' );
  $self->r->headers_out->set( 'X-DAS-Status',       $VALID_REQUEST );
  my $markup = sprintf
    qq(<?xml version="1.0" encoding="UTF-8" ?>\n<?xml-stylesheet type="text/xsl" href="/core/css/das.xsl"?>\n<DASDSN>%s</DASDSN>),
    join q(),
    map { $_->{'dsn_doc'} }
    $self->filtered_sources;
  return $self->xml->set_length( length $markup )->print( $markup )->ok;
}


1;
