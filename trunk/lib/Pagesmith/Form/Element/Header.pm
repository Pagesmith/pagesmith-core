package Pagesmith::Form::Element::Header;

##
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

use base qw( Pagesmith::Form::Element );

sub init {
  my $self = shift;
  return;
}

sub render {
  my $self = shift;
  return sprintf qq(\n    <dt class="spanning"><h4>%s</h4></dt>), $self->caption;
}

sub render_email {
  my $self = shift;
  return sprintf qq(\n%s\n\n), $self->caption;
}
1;
