package Pagesmith::Form::Element::PosInt;
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

use base qw( Pagesmith::Form::Element::NonNegInt);

sub validate {
  my $self = shift;
  return $self->set_valid unless defined $self->value;
  return $self->set_invalid if $self->value eq q(0);
  if( $self->value =~ m{\A[+]?\d+\Z}mxs ) {
    return $self->set_invalid if $self->max && $self->max < $self->value;
    return $self->set_valid;
  }
  return $self->set_invalid;
}

sub element_class {
  my $self = shift;
  $self->add_class( qw(_posint short) );
  return;
}
1;
