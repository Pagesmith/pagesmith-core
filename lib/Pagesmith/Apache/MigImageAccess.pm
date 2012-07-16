package Pagesmith::Apache::MigImageAccess;

## Apache Access Handler for MigImage data....
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

use Pagesmith::Adaptor::MigImage;
use Apache2::Const qw(FORBIDDEN OK);

my $adap;

sub handler {
  my $r = shift;
  (my $uri = $r->uri) =~ s{thumb(.\w+)\Z}{$1}mxgs; ## Trim out thumb for thumbnails....
  $adap ||= Pagesmith::Adaptor::MigImage->new;
  return $adap->can_serve( $uri ) ? OK : FORBIDDEN;
}

1;
