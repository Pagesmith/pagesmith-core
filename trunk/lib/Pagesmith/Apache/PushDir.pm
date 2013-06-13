package Pagesmith::Apache::PushDir;

## Apache wrapper for HTML files
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;

use version qw(qv); our $VERSION = qv('0.1.0');

use utf8;

use Apache2::Const qw(DONE);

sub handler {
  my $r = shift;
  $r->headers_out->set( 'Location' => $r->uri.q(/) );
  $r->headers_out->set( 'Status'   => '302 Found' );
  $r->status_line(      'HTTP/1.1 302 Found' );
  $r->status(           '302' );
  return DONE;
}

1;
