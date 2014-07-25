package Pagesmith::Form::Element::AutoComplete;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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
use HTML::Entities qw(encode_entities);
use Const::Fast qw(const);

const my $DEFAULT_QUERY  => 'query';


use base qw( Pagesmith::Form::Element::String );

sub widget_type {
  return 'string';
}

sub init {
  my $self = shift;
  $self->{'url'}        = exists $self->{'_options'}{'url' }       ? $self->{'_options'}{'url'}        : $self->form_config->form_url."?autocomplete=$self->{'code'}";
  $self->{'query_name'} = exists $self->{'_options'}{'query_name'} ? $self->{'_options'}{'query_name'} : $self->{'code'} || $DEFAULT_QUERY;
  return $self;
}

sub set_url {
  my( $self, $url ) = @_;
  $self->{'url'} = $url;
  return $self;
}

sub set_query_name {
  my( $self, $url ) = @_;
  $self->{'query_name'} = $url;
  return $self;
}

sub element_class {
  my $self = shift;
  $self->add_class( 'auto_complete' );
  return;
}

sub extra_markup {
  my $self = shift;
  return 'autocomplete="off"';
}

sub render_widget {
  my $self = shift;
  return $self->add_class( q(james), $self->encode($self->json_encode( {
      'varname'=>$self->{'query_name'},
      'url'    =>$self->{'url'},
  })))->SUPER::render_widget;
}
1;
