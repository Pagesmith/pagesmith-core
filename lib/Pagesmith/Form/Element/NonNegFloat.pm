package Pagesmith::Form::Element::NonNegFloat;

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

sub init {
  my $self = shift;
  return;
}

sub validate {
  my $self = shift;
  return $self->set_valid if $self->value =~ m{\A(?=\d|[.]\d)\d*(?:[.]\d*)?(?:[Ee][+-]?\d+)?\Z}mxs;
  return $self->set_invalid;
}

sub element_class {
  my $self = shift;
  return $self->add_class( '_nonnegfloat', 'short' );
}

1;
