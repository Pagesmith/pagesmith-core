package Pagesmith::Form::ElementTmp::RadioGroup;

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

use base  qw( Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

sub new {
  my( $class, %params ) = @_;
  my $self = $class->SUPER::new( %params, 'render_as' => $params{'select'} ? 'select' : 'radiobutton', 'values' => $params{'values'} );
  return $self;
}

sub validate {
  my $self = shift;
  return $self->render_as eq 'select';
}

sub render {
  my $self =shift;

  my $output = q();
  my $K = 0;
  foreach my $V ( @{$self->values} ) {
    my $checked = 'no';
    # check if we want to tick this box
    foreach my $M ( @{$self->value||[]} ) {
      if ($M eq $V->{'value'}) {
        $checked = 'yes';
        last;
      }
    }
    $checked = 'yes' if $V->{'checked'} eq 'yes';
    $output .= sprintf qq(\n<tr>\n<td></td>\n<td><label class="label-radio">\n<input type="radio" name="%s" id="%s_%d" value="%s" class="input-radio" %s/> %s </label></td>\n</tr>),
      encode_entities($self->name),
      encode_entities($self->name), $K,
      encode_entities($V->{'value'}),
      $checked eq 'yes' ? ' checked="checked"' : q(),
      $self->{'noescape'} ? $V->{'name'} : encode_entities($V->{'name'})
    ;
    $K++;
  }
  return $self->introduction.$output.$self->notes;

}

1;
