package Pagesmith::Form::ElementTmp::RadioButton;

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

use base qw(Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

sub new {
  my( $class, %params ) = @_;
  my $self = $class->SUPER::new(
    %params,
  );
  $self->{'checked'}  = $params{'checked'};
  $self->{'disabled'} = $params{'disabled'};
  return $self;
}

sub checked {
  my $self = shift;
  return $self->{'checked'};
}
sub disabled {
  my $self = shift;
  return $self->{'disabled'};
}

sub render {
  my $self = shift;

  return sprintf
    qq(<tr>\n  <th><label class="label-radio"></th>\n  <td><input type="radio" name="%s" id="%s" value="%s" class="input-radio"%s%s/> %s %s</label></td>\n</tr>),
    encode_entities( $self->name ),
    encode_entities( $self->id ),
    $self->value || 'yes',
    $self->checked ? ' checked="checked" ' : q(),
    $self->disabled ? ' disabled="disabled" ' : q(),
    encode_entities( $self->label ),
    $self->notes
  ;
}

sub validate {
  return 1;
}


1;
