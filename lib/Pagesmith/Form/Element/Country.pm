package Pagesmith::Form::Element::Country;

## Create a "Country" dropdown
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

use Pagesmith::Form::Constants qw(COUNTRIES);

sub _init {
  my $self = shift;
  return $self
    ->set_values( COUNTRIES )
    ->set_raw
    ->set_firstline( '== Select a country ==' )
    ->set_print_as_box;
}

1;
