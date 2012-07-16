package Pagesmith::Form::ElementTmp::Raw;

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

use HTML::Entities qw(encode_entities);

## Module for rendering arbitrary form elements using raw XHTML
## USE WITH CAUTION!!

sub render {
  my $self = shift;
  return $self->{'caption'};
}


1;
