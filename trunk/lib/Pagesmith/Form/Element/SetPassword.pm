package Pagesmith::Form::Element::SetPassword;

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

use Const::Fast qw(const);
const my $DEF_STRENGTH => q(normal);
const my %STRENGTHS    => qw(vweak 1 weak 1 normal 1 strong 1 vstrong 1 vvstrong 1);

# vweak    >= 1 character
# weak     >= 4 characters
# normal   >= 8 characters
# strong   >= 8 characters ( 2 of lc, uc, number, symbol )
# vstrong  >= 8 characters ( 3 of lc, uc, number, symbol )
# vvstrong >= 8 characters ( all of lc, uc, number, symbol )
use version qw(qv); our $VERSION = qv('0.1.0');

use base qw( Pagesmith::Form::Element::String );

sub new {
  my( $class, @params ) = @_;
  return $class->SUPER::new(
    @params,
    'style'    => 'short',
    'strength' => $DEF_STRENGTH,
  );
}

sub set_strength {
  my( $self, $v ) = @_;
  $self->{'strength'} = $v if exists $STRENGTHS{$v};
  return $self;
}

sub strength {
  my $self = shift;
  return $self->{'strength'};
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

sub render_value {
  my $self = shift;
  return q();
}

sub extra_markup {
  my $self = shift;
  return q( autocomplete="off").$self->SUPER::extra_markup;
}

1;
