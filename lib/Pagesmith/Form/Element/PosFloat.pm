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
  return $class->SUPER::new( @par, 'style' => 'short' );
}

sub _is_valid {
  my $self = shift;
  return $self->value =~ m{\A([+]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?\Z}mxs;
}

sub _class {
  return '_posfloat';
}
1;
