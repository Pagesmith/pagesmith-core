package Pagesmith::Form::Element::Float;

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

sub _init {
  my $self = shift;
  $self->style = 'short';
  return;
}

sub validate {
  my $self = shift;
  $self->set_valid( $self->value =~ m{\A([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\Z}mxs );
  return 1;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_float', 'short' );
  return;
}

1;
