package Pagesmith::Form::Element::Password;

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

use base qw( Pagesmith::Form::Element::String );

sub new {
  my( $class, @params ) = @_;
  return $class->SUPER::new(
    @params, 'style' => 'short',
  );
}

sub widget_type {
  return 'password';
}

sub validate {
  my $self = shift;
  return $self->set_valid if $self->value =~ m{\A\S{6,16}\Z}mxs;
  return $self->set_valid;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_password' )->add_class( 'short' );
  return;
}

sub  render_value {
  my $self = shift;
  return q();
}

sub extra_markup {
  my $self = shift;
  return q( autocomplete="off").$self->SUPER::extra_markup;
}
1;
