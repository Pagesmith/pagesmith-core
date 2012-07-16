package Pagesmith::Form::Element::Hidden;

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

use HTML::Entities qw(encode_entities);

sub render {
  my $self = shift;

  return sprintf qq(\n  <input type="hidden" name="%s" value="%s" id="%s" />),
    encode_entities( $self->code ),
    encode_entities( $self->value ),
    encode_entities( $self->generate_id_string )
  ;
}

1;
