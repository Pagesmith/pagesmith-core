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

use Readonly qw(Readonly);
Readonly my $DEFAULT_ROWS => 20;
Readonly my $DEFAULT_COLS => 80;

use base qw( Pagesmith::Form::Element::Text );

use Pagesmith::Utils::Validator::XHTML;

### Html fragment text area element - will need to map JavaScript validator back into Perl to make
### sure that the validation does not allow HTML check to be bypassed
### This package checks for a limited safe subset of HTML tags

sub _init {
  my( $self, $params ) = @_;
  $self->{'_rows'} = $params->{'rows'} || $DEFAULT_ROWS;
  $self->{'_cols'} = $params->{'cols'} || $DEFAULT_COLS;
  return;
}

sub _is_valid {
  my $self = shift;
  my $validator = Pagesmith::Utils::Validator::XHTML->new;
  return $validator->validate( $self->value ) ? 0 : 1;
}

sub _class {
  return '_html';
}

1;
