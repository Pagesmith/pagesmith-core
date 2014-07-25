package Pagesmith::Form::Element::String;

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
      defined  $self->value ? ( $self->raw ? $self->render_value( $self->value ) : encode_entities( $self->render_value( $self->value ) ) ) : q(),
      $self->generate_id_string,
      $self->generate_class_string,
      $self->size || $DEFAULT_SIZE,
      $self->extra_markup||q(),
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
