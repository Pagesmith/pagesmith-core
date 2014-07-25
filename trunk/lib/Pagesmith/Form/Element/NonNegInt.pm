package Pagesmith::Form::Element::NonNegInt;

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


use base qw( Pagesmith::Form::Element::String );

sub init {
  my($self,$element_data) = @_;
  $self->{'_max'}   = $element_data->{'max'};
  $self->{'_class'} = 'short';
  return;
}

sub set_max {
  my ($self,$max) = @_;
  $self->{'_max'} = $max;
  return $self;
}

sub max {
  my $self = shift;
  return $self->{'_max'};
}

sub validate {
  my $self = shift;
  return $self->set_valid unless defined $self->value;
  if( $self->value =~ m{\A[+]?\d+\Z}mxs ) {
    return $self->set_invalid if $self->max && $self->max < $self->value;
    return $self->set_valid;
  }
  return $self->set_invalid;
}

sub render_widget {
  my $self = shift;
  $self->add_class( 'max_'.$self->max ) if $self->max;
  return $self->SUPER::render_widget;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_nonnegint' );
  $self->add_class( 'short' );
  return;
}

sub required_string {
  my $self = shift;
  return $self->SUPER::required_string . ($self->max ? sprintf ' (Maximum of %d)', $self->max : q());
}
1;
