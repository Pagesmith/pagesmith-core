package Pagesmith::Form::ElementTmp::MultiSelect;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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

sub init {
  my( $self, $params ) = @_;
  $self->{'render_as'}  = $params->{'select'} ? 'select' : 'radiobutton';
  $self->{'values'}     = $params->{'values'};
  return $self;
}

sub validate {
  my $self = shift;
  return $self->render_as eq 'select';
}

sub render {
  my $self =shift;

  #cluck "This is how we got here!";

  if( $self->render_as eq 'select' ) {
    my $options = q();
    foreach my $V( @{$self->values} ) {
      my $checked = 'no';
      foreach my $M ( @{$self->value||[]} ) {
        if ($M eq $V->{'value'}) {
          $checked = 'yes';
          last;
        }
      }
      if ($V->{'checked'}) {
        $checked = 'yes';
      }
      $options .= sprintf qq(<option value="%s"%s>%s</option>\n),
        $V->{'value'}, $checked eq 'yes' ? ' selected="selected"' : q(), $V->{'name'}
      ;
    }
    my $label = $self->label ? encode_entities(
 $self->label ).': ' : q();
    return sprintf qq(\n    <tr>\n      <th><label for="%s">%s</label></th>\n      <td>%s<select multiple="multiple" name="%s" id="%s" class="normal" size="%s">\n      %s\n      </select>\n      %s</td>\n    </tr>),
      encode_entities( $self->id ),
      $label,
      $self->introduction,
      encode_entities( $self->name ),
      encode_entities( $self->id ),
      $self->size,
      $options,
      $self->notes
    ;
  } else {
    my $output = sprintf qq(\n    <tr>\n    <th><label class="label" for="%s">%s</label></th>\n    <td>),
      encode_entities($self->id),
      encode_entities($self->label )
    ;
    my $K = 0;
    my $separator = @{$self->values} > 2 ? 1 : 0;

    foreach my $V ( @{$self->values} ) {
      my $checked = 'no';
      # check if we want to tick this box
      foreach my $M ( @{$self->value||[]} ) {
        if ($M eq $V->{'value'}) {
          $checked = 'yes';
          last;
        }
      }
      $checked = 'yes' if $V->{'checked'};
      $output .= '<p>' if $separator;
      $output .= sprintf qq(\n<input type="checkbox" name="%s" id="%s_%d" value="%s" class="input-checkbox" %s /> %s),
        encode_entities($self->name),
        encode_entities($self->id),
        $K,
        encode_entities($V->{'value'}),
        $checked eq 'yes' ? ' checked="checked"' : q(),
        encode_entities($V->{'name'})
      ;
      $output .= '</p>' if $separator;
      $K++;
    }

    # To deal with the case when all checkboxes get unselected we intoduce a dummy
    # hidden field that will force APR to pass the parameter to our script
    $output .= sprintf  qq(\n    <input id="%s_%d" type="hidden" name="%s" value="" />),
      encode_entities($self->id),
      $K,
      encode_entities($self->name),
    ;
    $output .= qq(\n</td>\n    </tr>);
    return $self->introduction.$output.$self->notes;
  }
}

1;
