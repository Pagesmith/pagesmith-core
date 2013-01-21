package Pagesmith::Form::Element::Password;

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
  my( $class, @params ) = @_;
  return $class->SUPER::new(
    @params, 'style' => 'short',
  );
}

sub extra_markup {
  return 'autocomplete="off" ';
}
sub widget_type {
  return 'password';
}

sub validate {
  my $self = shift;
  return $self->set_valid if $self->value =~ m{\A\S{6,16}\Z}mxs;
  return $self->set_invalid;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_password' )->add_class( 'short' );
  return;
}

sub  render_value {
  my $self = shift;
  return q();
}

sub extra_markup {
  my $self = shift;
  return q( autocomplete="off").$self->SUPER::extra_markup;
}
1;
