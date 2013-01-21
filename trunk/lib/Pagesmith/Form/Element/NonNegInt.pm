package Pagesmith::Form::Element::NonNegInt;
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
  my($self,$element_data) = @_;
  $self->{'_max'}   = $element_data->{'max'};
  $self->{'_class'} = 'short';
  return;
}
sub max {
  my $self = shift;
  return $self->{'_max'};
}

sub validate {
  my $self = shift;
  return $self->set_valid  if $self->value =~ m{\A[+]?\d+\Z}mxs;
  return $self->set_invalid;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_nonnegint' );
  $self->add_class( 'short' );
  $self->add_class( 'max_'.$self->max ) if $self->max;
  return;
}

sub required_string {
  my $self = shift;
  return $self->SUPER::required_string . ($self->max ? sprintf ' (Maximum of %d)', $self->max : q());
}
1;
