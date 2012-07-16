package Pagesmith::Form::ElementTmp::NoEdit;
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

sub render {
  my $self = shift;
  my $value = $self->value || '&nbsp;';
  return sprintf qq(\n    <tr>\n      <th><label for="%s">%s: </label></th>\n      <td><div id="%s">%s</div></td>\n    </tr>),
    $self->name, $self->label, $self->name, $value
  ;
}

1;
