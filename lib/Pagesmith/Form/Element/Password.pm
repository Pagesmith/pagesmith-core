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

sub widget_type {
  return 'password';
}

sub _is_valid {
  my $self = shift;
  return $self->value =~ m{\A\S{6,16}\Z}mxs;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_password' )->add_class( 'short' );
  return;
}

sub _render_value {
  my $self = shift;
  return q();
}

1;
