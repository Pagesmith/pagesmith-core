package Pagesmith::Form::Element::Html;

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

use Const::Fast qw(const);
const my $DEFAULT_ROWS => 20;
const my $DEFAULT_COLS => 80;

use base qw( Pagesmith::Form::Element::Text );

use Pagesmith::Utils::Validator::XHTML;

### Html fragment text area element - will need to map JavaScript validator back into Perl to make
### sure that the validation does not allow HTML check to be bypassed
### This package checks for a limited safe subset of HTML tags

sub init {
  my( $self, $params ) = @_;
  $self->{'_rows'} = $params->{'rows'} || $DEFAULT_ROWS;
  $self->{'_cols'} = $params->{'cols'} || $DEFAULT_COLS;
  return;
}

sub validate {
  my $self = shift;
  my $validator = Pagesmith::Utils::Validator::XHTML->new;
  return $self->set_invalid if $validator->validate( $self->value );
  return $self->set_valid;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_html' );
  return;
}


1;
