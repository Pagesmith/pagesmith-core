package Pagesmith::Form::ElementTmp::Range;

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

# BROKEN
sub render {
  my $self = shift;
  my( $min, $max ) = $self->value ? ( 1, $self->value ) : ( q(),q() );
  if( $self->value =~ m{\A(.*):(.*)\Z}mxs ) {
    $min = $1;
    $max = $2;
  }
  my $extra = sprintf q(class="%s" onKeyUp="os_check('%s',this,%s)" onChange="os_check( '%s', this, %s )" ),
    'range',
    'range',
    $self->is_required ? 1 : 0,
    'range',
    $self->is_required ? 1 : 0
  ;
  return sprintf '%s<input type="text" name="%s_min" value="%s" id="%s_min" %s /> - <input type="text" name="%s_max" value="%s" id="%s_max" %s />%s%s',
    $self->introduction,
    encode_entities( $self->name ),
    encode_entities( $min ),
    encode_entities( $self->id ),
    $extra,
    encode_entities( $self->name ),
    encode_entities( $max ),
    encode_entities( $self->id ),
    $extra,
    $self->req_opt_string,
    $self->notes,
  ;
}

1;
