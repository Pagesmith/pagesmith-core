package Pagesmith::Form::Element::String;

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

use Const::Fast qw(const);
const my $DEFAULT_SIZE => 20;

use base qw( Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

sub init {
  my $self = shift;
  $self->{'size'} = $self->{'_options'}{'size'} || $DEFAULT_SIZE;
  return;
}

sub size {
  my $self = shift;
  return $self->{'size'};
}

sub set_size {
  my( $self, $size ) = @_;
  $self->{'size'} = $size;
  return $self;
}

sub element_class {
  my $self = shift;
  return $self->add_class( '_string' );
}

sub widget_type {
  return 'text';
}

sub validate {
  my $self = shift;
  return $self->set_valid;
}

sub render_widget_paper {
  my $self = shift;

  my $class = $self->generate_class_string =~ m{short}mxs ? 'bordered_short' : 'bordered';
  return sprintf '<div class="%s">%s</div>%s',
    $class,
    $self->render_widget_readonly,
    $self->req_opt_string,
  ;
}

sub render_value {
  my( $self, $val ) = @_;
  return $val;
}

sub render_widget {
  my $self = shift;
  if( $self->multiple ) {
    return sprintf '<input type="%s" name="%s" value="%s" id="%s" class="%s" size="%s" %s/>%s',
      $self->widget_type,
      encode_entities( $self->code ),
      q(),
      $self->generate_id_string,
      $self->generate_class_string,
      $self->size || $DEFAULT_SIZE,
      $self->extra_markup,
      join q(),
        $self->multiple_button,
        $self->req_opt_string,
        $self->multiple_markup,
    ;
  } else {
    return sprintf '<input type="%s" name="%s" value="%s" id="%s" class="%s" size="%s" %s/>%s',
      $self->widget_type,
      encode_entities( $self->code ),
      ( $self->raw ? $self->render_value( $self->value ) : encode_entities( $self->render_value( $self->value ) ) ),
      $self->generate_id_string,
      $self->generate_class_string,
      $self->size || $DEFAULT_SIZE,
      $self->extra_markup,
      $self->req_opt_string
     ;
  }
}

sub extra_markup {
  return q();
}

sub multiple_button {
  my $self = shift;
  return q() unless $self->multiple;
  return '<input type="button" class="add_entry" value="+" />';
}

1;
