package Pagesmith::Form::Element::Age;

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
Readonly my $MAX_AGE => 150;

use base qw( Pagesmith::Form::Element::String);

sub _init {
  my( $self, $params ) = @_;
  $self->style = 'short';
  return;
}

sub _is_valid {
  my $self = shift;
  return $self->value =~ m{\A\d+\Z}mxs && $self->value > 0 && $self->value <=$MAX_AGE;
}

sub _class {
  return '_age';
}

1;
