package Pagesmith::Form::ElementTmp::Range;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

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
