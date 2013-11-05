package Pagesmith::Form::Element::Composite;

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

use base qw( Pagesmith::Form::Element::DropDown );

use HTML::Entities qw(encode_entities);

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
  my $self = shift;
  $self->{'elements'}      = {};
  $self->{'element_order'} = [];
  return $self;
}

sub add {
  my( $self, $element ) = @_;
  my $id = $element->id;
  push @{$self->{'element_order'}}, $id unless exists $self->{'elements'}{$id};
  $self->{'elements'}{$id} = $element;
  return $element;
}

sub element_class {
  my $self = shift;
  return;
}

sub elements {
  my $self = shift;
  return map { $self->{'elements'}{$_} } @{$self->{'element_order'}};
}

sub render_widget_paper {
  my $self = shift;
  return join q(), map {
    $_->caption.$_->render_widget_paper
  } $self->elements;
}

sub render_widget_readonly {
  my $self = shift;
  return join q(), map { $_->caption.$_->render_widget_readonly } $self->elements;
}

sub render_widget {
  my $self = shift;
  return join q(), map { sprintf '<label for="%s">%s%s</label>%s',
    $_->generate_id_string,
    $_->hidden_caption ? '<span class="hidden">'.$self->encode( $_->hidden_caption ).'</span>' : q(),
    $_->caption,
    $_->render_widget
  } $self->elements;
}

1;
