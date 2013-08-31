package Pagesmith::Action::Now;

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
use Date::Format qw(time2str);

sub run {
  my $self = shift;

  return $self->text->print( time2str( "It is %A %o %B at %l.%M%P\n", time) )->ok;
}

1;

