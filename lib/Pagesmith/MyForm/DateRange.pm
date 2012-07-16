package Pagesmith::MyForm::DateRange;

## Industry day form set up...
##
## Author         : kg1
## Maintainer     : kg1
## Created        : 2011-09-05
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Readonly qw(Readonly);

Readonly my $FIRST_YEAR => 2011;

use base qw(Pagesmith::MyForm);

## Form creation code!
sub populate_object_values {
  my $self = shift;
  return $self;
}

sub initialize_form {
#@param (self)
  my $self = shift;
  ## no critic (LongChainsOfMethodCalls ImplicitNewlines)
  $self->add_class(  'form',                 'check' )          # Javascript validation is enabled
       ->add_class(  'form',                 'daterangeform' )
       ->add_class(  'section',              'panel' )          # Form sections are wrapped in panels
       ->set_option( 'no_reset' ,     1 )
       ->set_option( 'cancel_button', 0 )
       ->make_form_get
       ->set_view_url( undef )
       ;
  $self->add_stage( 'config' )->set_next( 'Run' );
  $self->add_section( 'config' );
    $self->add( 'Date', 'start' )->today->year_range($FIRST_YEAR,undef)->use_3letter_month();
    $self->add( 'Date', 'end'   )->today->year_range($FIRST_YEAR,undef)->use_3letter_month();
  $self->add_final_stage( 'test ');
  $self->update_from_apr;
  return $self;
}

sub overide_url {
  my $self = shift;
  return q(#);
}

1;