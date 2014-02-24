package Pagesmith::Action::Gone;

## Dumps raw HTML of the file to the browser (syntax highlighted)
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
use Apache2::Const qw(HTTP_GONE);
# Modules used by the code!

sub run {
  my $self = shift;
  $self->html;
  return HTTP_GONE;
}

1;
