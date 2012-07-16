package Pagesmith::Form::Element::Information;

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

sub is_input {
  my $self = shift;
  return 0;
}

sub is_required {
  my $self = shift;
  return 0;
}

sub render_readonly {
  my $self = shift;
  return q() if $self->hidden_readonly;
  return $self->render;
}

sub render_paper {
  my $self = shift;
  return $self->render;
}

sub render {
  my $self = shift;
  return sprintf qq(\n      <dt class="hidden">Information</dt>\n      <dd class="information">%s\n      </dd>), $self->caption;
}

1;
