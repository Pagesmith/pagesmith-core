package Pagesmith::Form::Section;

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

use base qw( Pagesmith::Form::Root );

use Carp qw(carp);
use Digest::MD5 qw(md5_hex);
use List::Util qw(first);
use List::MoreUtils qw(any);
use HTML::Entities qw(encode_entities);

my $_offset = 0;

sub r {
  my $self = shift;
  return $self->{'r'};
}

sub new {
  my ( $class, $page, $section_data ) = @_;
  my $self = {
    'object'          => $page->object,
    'config'          => $page->form_config,
    'id'              => $section_data->{'id'} || $page->form_config->next_id,
    'r'               => $page->r,
    'classes'         => { map { $_=>1 } $page->form_config->classes('section') },
    'caption'         => $section_data->{'caption'},
    'logic'           => [],
    'elements'        => {},
    'element_order'   => [],
    'enabled'         => 'yes',
    'required'        => 'yes',
    'current_group'   => q(-),
    'groups'          => { q(-) => [] },
  };

  bless $self, $class;
  return $self;
}

#h2 Checks on the form

sub validate {
  my( $self, $form ) = @_;
  return $self if $self->has_logic && ! $form->evaluate_logic( $self );
  # foreach( $self->elements ) {
  #   $_->validate( $form );
  #   warn sprintf ">> %s : %s/%s/%s=%s\n",
  #     $_->code, $_->is_empty, $_->is_required, $_->is_invalid,
  #     $_->is_empty ? $_->is_required : $_->is_invalid;
  # }
  $_->validate( $form ) foreach $self->elements;
  return $self;
}

sub is_invalid {
  my $self = shift;
  ## Return true if any element is required & empty
  ## Return true if any element is not empty and invalid
  return any { $_->is_empty ? $_->is_required : $_->is_invalid } $self->elements;
}

sub has_input_elements {
  my $self = shift;
  return any { $_->is_input } $self->elements;
}

#h2 accessors
sub form_config {
  my $self = shift;
  return $self->{'config'};
}

sub update_from_apr {
  my( $self, $apr, $flag ) = @_;
  $_->update_from_apr( $apr, $flag ) foreach $self->elements;
  return $self;
}

#= Class manipulation functions...
# Allows classes to be added to all sections (e.g. adding panel class to give
# them rounded borders etc) or all elements

sub current_group {
  my $self = shift;
  return $self->{'current_group'};
}

sub current_element {
  my $self = shift;
  return $self->{'current_element'};
}

sub classes {
#@param (self)
#@return (string+) list of classes
## Return the list of classes associated with the form!
  my $self =shift;
  my @classes = sort keys %{ $self->{'classes'} };
  return @classes;
}

sub add_class {
#@param (self)
#@param (string) $class CSS class to add to form
  my ( $self, $class ) = @_;
  $self->{'classes'}{$class} = 1;
  return $self;
}

## Accessors
sub set_id {
  my( $self, $value ) = @_;
  $self->{'id'} = $value;
  return $self;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub set_caption {
  my( $self, $value ) = @_;
  $self->{'caption'} = $value;
  return $self;
}

sub caption {
  my $self = shift;
  return $self->{'caption'};
}

#= Element manipulation functions

sub renderable_elements {
#@param (self)
#@return (Pagesmith::Form::Element::+) Array of elements!
  my $self = shift;
  return map { $self->{'elements'}{$_} } @{ $self->{'element_order'} };
}

sub elements {
  my $self = shift;
  return values %{$self->{'elements'}}; ## return all values including those in children!
}

sub has_file_no_ignored {
  my $self = shift;
  return any { $_->has_file_no_ignored } $self->elements;
}

sub has_file {
  my $self = shift;
  return any { $_->has_file } $self->elements;
}

## Adding elements...

sub set_object {
  my( $self, $value ) = @_;
  $self->{'object'} = $value;
  return $self;
}

sub object {
  my $self = shift;
  return $self->{'object'};
}

sub add_button_html {
  my( $self, $position, $html ) = @_;
  $self->{'button_html'}{$position} = $html;
  return $self;
}

sub remove_button_html {
  my( $self, $position ) = @_;
  delete $self->{'button_html'}{$position};
  return $self;
}

sub add_group {
  my( $self, $name, $type, $parent ) = @_;
  ## Add group with an existing name will just change current_group
  ## to that group;
  unless( exists $self->{'groups'}{$name} ) {
    $parent = q(-) unless defined $parent && exists $self->{'groups'}{$parent};
    $self->{'groups'}{$name} = [];
    push @{ $self->{'groups'}{$parent}}, [ $type, $name ];
    $self->{'has_groups'} = 1;
  }
  $self->{'current_group'} = $name;
  return;
}

sub add {

#@param (self)
#@param (string) $type Type of element to add
#@param (hashref) $options Configuration of the new element
#@return (Pagesmith::Form::Element::*) form element added
## Add a new element to the section

  my ( $self, $type_in, $id ) = @_;

  my $element_data = $type_in;

  unless( ref $element_data eq 'HASH' ) {
    $id ||= $self->form_config->next_id;
    $element_data = {
      'type'      => $type_in,
      'id'        => $id,
      'code'      => $id,
      'getter'    => "get_$id",
      'setter'    => "set_$id",
      'required'  => 'yes',
    };
  }
  my $type = $self->safe_module_name( $element_data->{'type'} );

  my $module = "Pagesmith::Form::Element::$type";

  if ( $self->dynamic_use($module) ) {
    $element_data = { 'id' => $element_data } unless ref $element_data;
    $element_data->{'id'} ||= $self->form_config->next_id;
    $id = $element_data->{'id'};

    my $flag_exists = exists $self->{'elements'}{$id};
    my $element = $module->new( $self, $element_data );
    unless( $element ) {
      carp "Unable to generate an element of module $module";
      return;
    }
    $self->{'elements'}{$id} = $element;
    push @{ $self->{'element_order'} }, $id unless $flag_exists;

    push @{ $self->{'groups'}{$self->current_group} }, $element; ## Push element onto group!

    $self->{'current_element'} = $self->{'elements'}{$id};
    return $element;
  } else {
    carp "Unable to dynamically use module $module. Have you spelt the element type correctly?";
    return;
  }
}

sub add_to_composite {

#@param (self)
#@param (string) $type Type of element to add
#@param (hashref) $options Configuration of the new element
#@return (Pagesmith::Form::Element::*) form element added
## Add a new element to the section

  my ( $self, $type_in, $id ) = @_;

  my $element_data = $type_in;

  unless( ref $element_data eq 'HASH' ) {
    $id ||= $self->form_config->next_id;
    $element_data = {
      'type'      => $type_in,
      'id'        => $id,
      'code'      => $id,
      'getter'    => "get_$id",
      'setter'    => "set_$id",
      'required'  => 'yes',
    };
  }
  my $type = $self->safe_module_name( $element_data->{'type'} );

  my $module = "Pagesmith::Form::Element::$type";

  if ( $self->dynamic_use($module) ) {
    $element_data = { 'id' => $element_data } unless ref $element_data;
    $element_data->{'id'} ||= $self->form_config->next_id;
    $id = $element_data->{'id'};

    my $flag_exists = exists $self->{'elements'}{$id};
    my $element = $module->new( $self, $element_data );
    unless( $element ) {
      carp "Unable to generate an element of module $module";
      return;
    }
    $self->current_element->add( $element );
    $self->{'elements'}{$id} = $element;
    ##push @{ $self->{'element_order'} }, $id unless $flag_exists;
    ##push @{ $self->{'groups'}{$self->current_group} }, $element; ## Push element onto group!

    return $element;
  } else {
    carp "Unable to dynamically use module $module. Have you spelt the element type correctly?";
    return;
  }
}

## Rendering
sub generate_id_string {
  my $self = shift;
  return sprintf 'section_%s_%s',
    encode_entities( $self->form_config->form_id ),
    encode_entities( $self->id );
}

sub base_render {
  my ( $self, $elements, $hidden ) = @_;

  my $output = sprintf qq(\n  <div id="%s"), $self->generate_id_string;
## Here we have to join in any classes...
  my $x = join q( ), $self->classes;

  $output .= sprintf ' class="%s"', $x if $x;
  $output .= q(>);
  if( $self->caption ) {
    $output .= "\n    <h3>" . encode_entities( $self->caption ) . '</h3>';
  } else {
    $output .= qq(\n    <div style="height:1px">&nbsp;</div>);
  }
  $output .= $self->{'button_html'}{'top'}    if exists $self->{'button_html'}{'top'};
  $output .= $elements;
  $output .= $self->{'button_html'}{'bottom'} if exists $self->{'button_html'}{'bottom'};
  $output .= $hidden;
  $output .= "\n  </div>";
  return $output;
}

sub render {
#@param (self)
#@return (HTML) Form rendered in HTML.
## Render the section of the form.
  my( $self, $form ) = @_;
  my $status = q();
  foreach my $logic_ref ( @{$self->logic}) {
    if( $logic_ref->{'action'} eq 'disable' ) {
      if( $self->evaluate_logic( $logic_ref ) ) {
        $status = 'disabled';
      } else {
        $status ||= 'enabled';
      }
    } else {
      if( $self->evaluate_logic( $logic_ref ) ) {
        $status = 'enabled';
      } else {
        $status ||= 'disabled';
      }
    }
  }
  return q() if $status eq 'disabled';
## Grab all the hidden elements....
## Now loop through the "groups" to generate the non-hidden elements HTML...
  my $hidden     = join q(), map { $_->render( $form ) } grep { ref($_) =~ m{Hidden}mxs } $self->renderable_elements;
  my $not_hidden = $self->render_group( q(-), $form ); ## Render the top level group....
  my $t = $self->base_render( $not_hidden, $hidden );
  return $t;
}

sub render_group {
  my( $self, $gp, $form, $dl_class, $render_mode ) = @_;
  my $class = defined $dl_class && $dl_class ? "clear $dl_class" : $dl_class;
  $render_mode = q() unless defined $render_mode;

  my $html             = q();
  my $drawing_elements = 0;
  foreach my $el (@{$self->{'groups'}{$gp}}) {
    if( ref $el eq 'ARRAY' ) { ## We have a group so render it!
      $html .= '</dl>' if $drawing_elements;
      $drawing_elements = 0;
      if( $el->[0] eq 'tabs' ) { ## We have a tab container - diff
        ## Generate tabs ul
        ## Generate tabs divs...
      } else {
        $html .= sprintf '<div class="%s">%s</div>',
          $el->[0],$self->render_group( $el->[1], $form, $dl_class, $render_mode );
      }
      next;
    }
    next if ref($el) =~ m{Hidden}mxs;
    $html .= '<dl class="clear">' unless $drawing_elements;
    $drawing_elements = 1;
    $html .= $render_mode eq 'readonly' ? $el->render_readonly( $form ) : $el->render( $form );
  }
  $html .= '</dl>' if $drawing_elements;
  return $html;
}

sub render_email {
  my( $self, $form ) = @_;
  return sprintf "\n%s\n%s", $self->caption, $self->render_email_group( q(-), $form );
}

sub render_email_group {
  my( $self, $gp, $form ) = @_;
  my $out = q();

  foreach my $el ( @{$self->{'groups'}{$gp}} ) {
    next if ref $el eq 'Hidden';
    if( ref($el eq 'ARRAY') ) {
      $out .= $self->render_email_group( $el->[1], $form );
      next;
    }
    $out .= "\n".$el->render_email( $form );
  }

  return $out;
}

sub render_readonly {

#@param (self)
#@return (HTML) Form rendered in HTML.
## Render the section of the form.
  my( $self, $form ) = @_;
  return q() if $self->has_logic && ! $form->evaluate_logic( $self );
  my $not_hidden = $self->render_group( q(-), $form, 'two_col', 'readonly' );
  my $t = $self->base_render( $not_hidden , q(), ' class="twocol"' );
  return $t;
}

sub render_paper {
#@param (self)
#@return (HTML) Form rendered in HTML.
## Render the section of the form.
  my( $self, $form ) = @_;
  return q() if $self->has_logic && ! $form->evaluate_logic( $self ); #??#
  my $not_hidden = join q(), map { $_->render_paper( $form ) } grep { ref($_)!~ m{Hidden}mxs } $self->renderable_elements;

  return $self->base_render( $not_hidden, q(), ' class="twocol"' );
}

1;
