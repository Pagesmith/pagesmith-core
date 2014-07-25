package Pagesmith::MyForm::DateRange;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

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

use Const::Fast qw(const);

const my $FIRST_YEAR => 2011;

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