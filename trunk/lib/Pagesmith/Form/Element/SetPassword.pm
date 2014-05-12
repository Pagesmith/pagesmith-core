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
const my $DEF_LENGTH   => 6;
const my $DEF_STRENGTH => q(normal);
const my %STRENGTHS  => qw(weak 1 normal 2 strong 3 vstrong 4);
const my %STRENGTH_NOTES => (
  'weak'    => q(),
  'normal'  => q(at least two of the following: a lower case letter, an upper case letter, a number or a non-alphanumeric symbol),
  'strong'  => q(at least three of the following: a lower case letter, an upper case letter, a number or a non-alphanumeric symbol),
  'vstrong' => q(at least one each of the following: a lower case letter, an upper case letter, a number or a non-alphanumeric symbol),
);
# vweak    >= 1 character
# weak     >= 4 characters
# normal   >= 8 characters
# strong   >= 8 characters ( 2 of lc, uc, number, symbol )
# vstrong  >= 8 characters ( 3 of lc, uc, number, symbol )
# vvstrong >= 8 characters ( all of lc, uc, number, symbol )

use version qw(qv); our $VERSION = qv('0.1.0');

use Const::Fast qw(const);
const my $FOUR  => 4;
const my $EIGHT => 8;
use base qw( Pagesmith::Form::Element::String );

sub new {
  my( $class, @params ) = @_;
  return $class->SUPER::new(
    @params,
    'style'    => 'short',
  )->set_strength( $DEF_STRENGTH, $DEF_LENGTH );
}

sub set_strength {
  my( $self, $v, $l ) = @_;
  $self->{'strength'} = $v if exists $STRENGTHS{$v};
  $self->{'length'}   = $l if defined $l;
  $self->set_notes( sprintf 'At least %d characters long containing %s',
    $self->{'length'}, $STRENGTH_NOTES{ $self->{'strength'} } );
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
  return $self->set_invalid if $self->{'length'} > length $self->value;
  return $self->set_invalid if $STRENGTHS{$self->{'strength'}} >
          ($self->value =~ m{[[:digit:]]}mxs)
        + ($self->value =~ m{[[:upper:]]}mxs)
        + ($self->value =~ m{[[:lower:]]}mxs)
        + ($self->value =~ m{[^[:upper:][:lower:][:digit:]]}mxs);
  return $self->set_valid;
}

sub element_class {
  my $self = shift;
  $self->add_class( 'medium' );
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

sub render_widget {
  my $self = shift;
  $self->add_class( q(_).$self->{'strength'}.'password' );
  $self->add_class( 'min_'.$self->{'length'} );
  return $self->SUPER::render_widget();
}
1;
