package Pagesmith::Action::Dump;

## Dumps the headers of the request to log file..., and returns
## 204 - no content so the page isn't refreshed...

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

  my $headers_in = $self->r->headers_in();
  foreach my $k ( sort keys %{$headers_in} ) {
    printf {*STDERR} "%20s = %s\n", $k, $headers_in->{$k};
  }
  return $self->no_content;
}

1;
