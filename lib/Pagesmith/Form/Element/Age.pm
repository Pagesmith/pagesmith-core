package Pagesmith::Form::Element::Age;

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

use Const::Fast qw(const);
const my $MAX_AGE => 150;

use base qw( Pagesmith::Form::Element::String);

sub init {
  my( $self, $params ) = @_;
  $self->style = 'short';
  return;
}

sub validate {
  my $self = shift;
  return $self->is_valid if $self->value =~ m{\A\d+\Z}mxs && $self->value > 0 && $self->value <=$MAX_AGE;
  return $self->is_invalid;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_age' );
  $self->add_class( 'short' );
  return;
}

1;
