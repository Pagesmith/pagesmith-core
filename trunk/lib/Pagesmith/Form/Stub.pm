package Pagesmith::Form::Stub;

## Form handling package
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

## Form child objects;

use base qw(Pagesmith::Form);

sub initialize_form {
  my $self = shift;
  return $self;
}

sub populate_object_values {
  my $self = shift;
  return $self;
}

sub populate_user_values {
  my $self = shift;
  return $self;
}

sub set_url {
  my ( $self, $url ) = @_;
  $self->{'submit_url'} = $url;
  return $self;
}

sub overide_url {
  my $self = shift;
  return $self->{'submit_url'};
}

sub make_simple {
  my $self = shift;
  ## no critic (LongChainsOfMethodCalls)
  $self
    ->add_class(  'form',     'check'          )
    ->add_class(  'form',     'cancel_quietly' )
    ->set_option( 'no_reset'                   )
    ->set_option( 'cancel_button',   0         )
    ->set_option( 'required_string', q()       )
    ->set_option( 'optional_string', q()       )
    ->make_form_get
    ->set_option( 'do_not_pass_ref' )
    ->add_stage('input')->set_next('Go');
  ## use critic
  return $self;
}

sub bake {
  my $self = shift;
  $self->update_from_apr->validate->add_confirmation_stage;
  return $self;
}

1;

