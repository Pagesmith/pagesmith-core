package Pagesmith::Form::Element::URL;
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

use base qw( Pagesmith::Form::Element::String );

use HTML::Entities qw(encode_entities);

sub validate {
  my $self = shift;
  return $self->set_valid if $self->value =~ m{\Ahttps?://\w.*\Z}mxs;
  return $self->set_invalid;
}

sub render_widget {
  my $self = shift;
  my $return = $self->SUPER::render_widget();
  $return .= sprintf '<p><%% Link -ajax -get_title %s %%></p>', encode_entities( $self->value ) if $self->value;
  return $return;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_url' );
  return;
}
1;
