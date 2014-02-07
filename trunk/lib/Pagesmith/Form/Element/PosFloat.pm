package Pagesmith::Form::Element::PosFloat;
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

sub new {
  my($class,@pars) = @_;
  return $class->SUPER::new( @pars, 'style' => 'short' );
}

sub validate {
  my $self = shift;
  return $self->set_valid   unless defined $self->value;
  return $self->set_invalid if $self->value == 0;
  return $self->set_valid   if $self->value =~ m{\A(?=\d|[.]\d)\d*(?:[.]\d*)?(?:[Ee][+-]?\d+)?\Z}mxs;
  return $self->set_invalid;
}

sub element_class {
  my $self = shift;
  $self->add_class( qw(_posfloat short) );
  return;
}
1;
