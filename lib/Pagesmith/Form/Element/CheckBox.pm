package Pagesmith::Form::Element::CheckBox;

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
const my $DEFAULT_ON_VALUE  => 'yes';
const my $DEFAULT_OFF_VALUE => 'no';

use base qw( Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

sub init {
  my $self = shift;
  $self->{'readonly_when_true'}  = exists $self->{'_options'}{'readonly_when_true' } ? $self->{'_options'}{'readonly_when_true'}  : 0;
  $self->{'on_value'}  = exists $self->{'_options'}{'on_value' } ? $self->{'_options'}{'on_value'}  : $DEFAULT_ON_VALUE;
  $self->{'off_value'} = exists $self->{'_options'}{'off_value'} ? $self->{'_options'}{'off_value'} : $DEFAULT_OFF_VALUE;
  $self->{'disabled'}  = $self->{'_options'}{'disabled'} || 0;
  $self->{'inline'}    = $self->{'_options'}{'inline'} || q();
  return $self;
}

sub update_from_apr {
  my( $self, $apr, $flag ) = @_;
  my $v = $apr->param( $self->code ) || $self->{'off_value'};
  $self->{'user_data'} = [$v eq $self->{'on_value'} ? $self->{'on_value'} : $self->{'off_value'}];
  return;
}

sub is_empty {
  my $self = shift;
  return $self->value ne $self->on_value;
}

sub set_inline {
  my( $self, $txt ) = @_;
  $self->{'inline'} = $txt;
  return $self;
}
sub on_value {
  my $self = shift;
  return $self->{'on_value'};
}

sub set_on_value {
  my( $self, $value ) = @_;
  $self->{'on_value'} = $value;
  return $self;
}

sub off_value {
  my $self = shift;
  return $self->{'off_value'};
}

sub set_off_value {
  my( $self, $value ) = @_;
  $self->{'off_value'} = $value;
  return $self;
}

sub set_readonly_when_true {
  my $self = shift;
  $self->{'readonly_when_true'} = 1;
  return $self;
}

sub clear_readonly_when_true {
  my $self = shift;
  $self->{'readonly_when_true'} = 0;
  return $self;
}
sub set_disabled {
  my( $self, $value ) = @_;
  $self->{'disabled'} = defined $value ? $value : 1;
  return $self;
}

sub disabled {
  my $self = shift;
  return $self->{'disabled'};
}

sub element_class {
  my $self = shift;
  $self->add_class( '_checkbox' );
  $self->add_layout( 'eighty20' );
  return;
}

sub render_readonly {
  my( $self, $form ) = @_;
  return q() if $self->{'readonly_when_true'} && $self->value ne $self->on_value;
  return $self->SUPER::render_readonly( $form );
}

sub render_value {
  my( $self, $val ) = @_;
  return $val;
}

sub render_email {
  my( $self, $form ) = @_;
  return q() if $self->{'readonly_when_true'} && $self->value ne $self->on_value;
  return $self->SUPER::render_email( $form );
}
sub render_widget_paper {
  my $self = shift;

  return sprintf '<div class="%s">%s</div>%s',
    'bordered_short',
    encode_entities( $self->value eq $self->on_value ? $self->on_value : $self->off_value ),
    $self->req_opt_string
  ;
}

sub render_widget {
  my $self = shift;
  return sprintf
    '<input type="checkbox" name="%s" id="%s" class="%s" value="%s"%s%s/>%s',
    encode_entities( $self->code ),
    $self->generate_id_string,
    $self->generate_class_string,
    encode_entities( $self->on_value ),
    $self->value eq $self->on_value ? ' checked="checked" '       : q(),
    $self->disabled                 ? ' disabled="disabled" '     : q(),
    $self->{'inline'}. $self->req_opt_string
  ;
}

sub validate {
  return 1;
}

1;
