package Pagesmith::Form::Element::Heading;

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

use HTML::Entities qw(encode_entities);

sub validate {
  my $self = shift;
  return $self->set_valid;
}
sub _init {
  my $self = shift;
  return;
}

sub is_input {
  my $self = shift;
  return 0;
}

sub is_required {
  my $self = shift;
  return 0;
}

sub render {
  my $self = shift;
  return sprintf qq(\n  </dl>\n  <h4 class="clear">%s</h4>\n  <dl>),
    encode_entities($self->caption)
  ;
}

sub render_readonly {
  my $self = shift;
  return sprintf qq(\n  </dl>\n  <h4 class="clear">%s</h4>\n  <dl class="twocol">),
    encode_entities($self->caption)
  ;
}

sub render_paper {
  my $self = shift;
  return $self->render_readonly;
}

1;
