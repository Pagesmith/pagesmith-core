package Pagesmith::Form::Element::DropDown;

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
use List::MoreUtils qw(any);

#--------------------------------------------------------------------
# Creates a form element for an option set, as either a select box
# or a set of radio buttons
# Takes an array of anonymous hashes, thus:
# my @values = (
#           {'name'=>'Option 1', 'value'=>'1'},
#           {'name'=>'Option 2', 'value'=>'2'},
#   );
# The 'name' element is displayed as a label or in the dropdown,
# whilst the 'value' element is passed as a form variable
#--------------------------------------------------------------------

sub init {
  my( $self, $element_data ) = @_;

  $element_data ||= {};

  if( exists $element_data->{'print_as'} && $element_data->{'print_as'} eq 'box' ) {
    $self->set_print_as_box;
  } else {
    $self->set_print_as_list;
  }
  return $self
    ->set_firstline(        $element_data->{'firstline'}       )
    ->set_firstline_value(  $element_data->{'firstline_value'} )
    ->set_values(           $element_data->{'values'}          )
    ;
}

sub set_sort_by_value {
  my $self = shift;
  $self->{'_sort_by_value'} = 1;
  return $self;
}

sub clear_sort_by_value {
  my $self = shift;
  $self->{'_sort_by_value'} = 0;
  return $self;
}

sub sort_by_value {
  my $self = shift;
  return $self->{'_sort_by_value'}||0;
}

sub set_firstline {
  my( $self, $value ) = @_;
  $self->{'_firstline'} = $value;
  return $self;
}

sub firstline {
  my $self = shift;
  return $self->{'_firstline'};
}

sub set_firstline_value {
  my( $self, $value ) = @_;
  $self->{'_firstline_value'} = $value||undef;
  return $self;
}

sub firstline_value {
  my $self = shift;
  return q() unless defined $self->{'_firstline_value'};
  return $self->{'_firstline_value'};
}

sub set_values {
  my( $self, $values ) = @_;
  $self->{'_values'} = $values;
  return $self;
}

sub add_values {
  my( $self, @values ) = @_;
  push @{$self->{'_values'}}, @values;
  return $self;
}

sub dropdown_values {
  my $self = shift;
  return map { { 'value' => $_, 'name' => $self->{'_values'}{$_} } }
         sort { $self->{'_values'}{$a} cmp $self->{'_values'}{$b} }
         keys %{$self->{'_values'}}
    if ref $self->{'_values'} eq 'HASH' && $self->sort_by_value;

  return map { { 'value' => $_, 'name' => $self->{'_values'}{$_} } } sort keys %{$self->{'_values'}}
    if ref $self->{'_values'} eq 'HASH';

  return @{ $self->{'_values'} || [] };
}

sub print_as {
  my $self = shift;
  return $self->{'_print_as'};
}

sub element_class {
  my $self = shift;
  $self->add_class( '_dropdown' );
  return;
}

sub set_print_as_box {
  my $self = shift;
  $self->{'_print_as'} = 'box';
  return $self;
}

sub set_print_as_list {
  my $self = shift;
  $self->{'_print_as'} = 'list';
  return $self;
}

sub render_widget_paper {
  my $self = shift;
  if( $self->print_as eq 'box' ) {
    my $class = $self->generate_class_string =~ m{short}mxs ? 'bordered_short' : 'bordered';
    return sprintf '<div class="%s">%s</div>',
      $class,
      $self->render_widget_readonly;
  }
  my $options = q();
  my $current_group = q();
  my $html = q();

  my %multiple_values = $self->multiple
                      ? map { ($_ => 1) } $self->multi_values
                      : ($_->value=>1);

  foreach my $V ( $self->dropdown_values ) {
    $V = {'value'=>$V,'name'=>$V} unless ref $V;
    if( exists $V->{'group'} && $V->{'group'} ne $current_group ) {
      if( $current_group ) {
        $options.="\n       </ul></li>";
      }
      if( $V->{'group'}) {
        $options.= sprintf qq(\n       <li>%s<ul>), encode_entities( $V->{'group'} );
      }
      $current_group = $V->{'group'};
    }
    my $extra = $multiple_values{ $V->{'value'} } ? 'X' : '&nbsp;&nbsp;';

    my $value = $V->{'name'} || $V->{'value'};
    $options .= sprintf qq(\n        <li><span>%s</span>%s</li>),
      $extra, $self->raw ? $value : encode_entities( $value );
  }
  if( $current_group ) {
    $options.="\n       </ul></li>";
  }

  return qq(<ul class="boxes">$options</ul>);
}

sub render_widget_readonly {
  my $self = shift;
  if( $self->multiple ) {
    my %multiple_values = map { ($_ => 1) } $self->multi_values;
    my @text = map { ( ref $_
                     ? ( exists $multiple_values{ $_->{'value'} } ? ($_->{'name'}) : () )
                     : ( exists $multiple_values{ $_            } ? ($_          ) : () ) ) }
      $self->dropdown_values;
    if( @text ) {
      return sprintf '<ul><li>%s</li></ul>',
        join '</li><li>',
        map { $self->raw ? $_ : encode_entities( $_ ) }
        @text;
    } else {
      return q(--);
    }
  } else {
    my $value  = $self->value;
    my ($text) = map { ( ref $_ ? ($_->{'value'} eq $value ? ($_->{'name'}) : ()) : ( $_ eq $value ? ($_) : () ) ) } $self->dropdown_values;
    $text = q(--) unless defined $text;
    return $self->raw ? $text : encode_entities( $text );
  }
}

sub render_widget {
  my $self = shift;
  my $options = q();
  my $current_group = q();
  if( $self->firstline ) {
    $options .= sprintf qq(\n         <option value="%s">%s</option>), encode_entities( $self->firstline_value ), encode_entities( $self->firstline );
  }
  my $optcount = 0;

  my $val             = $self->multiple ? q() : $self->value;
     $val = q() unless defined $val;
  my %multiple_values = $self->multiple ? map { ($_ => 1) } $self->multi_values : ();
  my @extra_multiple;

  # Generate the drop down...
  foreach my $V ( $self->dropdown_values ) {
    $V = {'value'=>$V,'name'=>$V} unless ref $V;
    if( exists $V->{'group'} && $V->{'group'} ne $current_group ) {
      if( $current_group ) {
        $options.="\n       </optgroup>";
      }
      if( $V->{'group'}) {
        my $group_class = q();
        $group_class = sprintf ' class="%s"', encode_entities( $V->{'group_class'} ) if exists $V->{'group_class'};
        $options.= sprintf qq(\n       <optgroup label="%s"%s>), encode_entities( $V->{'group'} ), $group_class;
      }
      $current_group = $V->{'group'};
    }
    # Deal with multivalued dropdown -> push results onto extra_multiple array we will render later!
    if( $self->multiple && exists $multiple_values{ $V->{'value'} } ) {
      push @extra_multiple, sprintf
        '<span class="close_box">%s<input type="hidden" value="%s" name="%s" /></span>',
          encode_entities($V->{'name'}), encode_entities($V->{'value'}), encode_entities( $self->code );
    }

    my $extra = !$self->multiple && $val eq $V->{'value'} ? ' selected="selected"' : q();
    my $value = $V->{'name'} || $V->{'value'};
    $options .= sprintf qq(\n        <option value="%s"%s>%s</option>),
      encode_entities( $V->{'value'} ),
      $extra,
      $self->raw ? $self->strip_html( $value ) : encode_entities( $self->strip_html( $value ) );
    $optcount++;
  }
  if( $current_group ) {
    $options.="\n       </optgroup>";
  }

  return sprintf qq(<select name="%s" id="%s" class="%s">%s\n      </select>%s),
    encode_entities( $self->code ), ## name=
    $self->generate_id_string,      ## id=
    $self->generate_class_string,   ## class=
    $options,                       ## <option>*
    join q(),
      $self->multiple_button,       ## "multiple button?"
      $self->req_opt_string,        ## Required/optional
      @extra_multiple;              ## already selected values
}

sub validate {
  my $self = shift;
  return $self->set_valid unless defined $self->value;
  my $t = $self->scalar_value;
  if( ref $self->{'_values'} eq 'HASH' ) {
    return $self->set_valid if exists $self->{'_values'}{ $t };
  } elsif( ref $self->{'_values'} eq 'ARRAY' ) {
    if( ref $self->{'_values'}[0] eq 'HASH' ) {
      return $self->set_valid if any { $t eq $_->{'value'} } @{$self->{'_values'}};
    } else {
      return $self->set_valid if any { $t eq $_ } @{$self->{'_values'}};
    }
  }
  return $self->set_invalid;
}

1;
