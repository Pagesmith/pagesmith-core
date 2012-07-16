package Pagesmith::Form::ElementTmp::ComboBox;

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

use base qw( Pagesmith::Form::Element );

sub _init {
  my( $self, $params ) = @_;
  $self->{'render_as'} = $params->{'select'} ? 'select' : 'radiobutton';
  return;
}

1;
