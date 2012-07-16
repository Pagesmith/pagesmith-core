package Pagesmith::Form::ElementTmp::Honeypot;

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

### Bogus textarea, hidden using CSS, designed to catch spambots!

sub render {
  my $self = shift;
  return sprintf qq(\n  <tr class="hide">\n    <th><label for="%s">%s: </label></th>\n    <td><textarea name="%s"></textarea>\n    </td>\n  </tr>),
    encode_entities( $self->name ),
    encode_entities( $self->label ),
    encode_entities( $self->name ),
  ;
}

1;
