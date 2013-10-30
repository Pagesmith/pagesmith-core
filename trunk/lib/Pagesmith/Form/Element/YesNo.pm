package Pagesmith::Form::Element::YesNo;

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

use base qw( Pagesmith::Form::Element::DropDown );

#--------------------------------------------------------------------
# Creates a form element for an option set, as either a select box
# or a set of radio buttons
# Takes an array of anonymous hashes, thus:
# my @values = (
#           {'name'=>'Option 1', 'value'=>'1'},
#           {'name'=>'Option 2', 'value'=>'2'},
#   );
# The 'name' element is displayed as a label or in the dropdown,
# whilst the 'value' element is passed as a form variable
#--------------------------------------------------------------------

sub init {
  my( $self, $element_data ) = @_;
  $self->add_layout( 'eighty20' );
  $element_data->{'values'} = [
    { 'value' => 'no', 'name' => 'No' },
    { 'value' => 'yes', 'name' => 'Yes' },
  ];
  $self->SUPER::init( $element_data );
  return;
}

sub value {
  my ($self, @extra ) = @_;
  return lc $self->SUPER::value( @extra );
}

1;
