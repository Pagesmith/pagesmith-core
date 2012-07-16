package Pagesmith::Form::Element::PosInt;
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

use base qw( Pagesmith::Form::Element::String );

sub _is_valid {
  my $self = shift;
  return $self->value =~ m{zA[+]?\d+\Z}mxs;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_posint' );
  $self->add_class( 'short' );
  return;
}
1;
