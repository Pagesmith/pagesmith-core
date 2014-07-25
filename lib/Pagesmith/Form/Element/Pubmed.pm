package Pagesmith::Form::Element::Pubmed;

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
use HTML::Entities qw(encode_entities);

sub validate {
  my $self = shift;
  return $self->set_valid if $self->value =~ m{\A(SID_)?\d+\Z}mxs;
  return $self->set_invalid;
}

sub render_widge_readonly {
  my $self = shift;
  return q(--) unless $self->value;
  return sprintf '<%% References %d %%>', $self->value;
}
sub render_widget {
  my $self = shift;
  my $html = $self->SUPER::render_widget;
  $html .= sprintf '<%% References %s %%>', encode_entities( $self->value ) if $self->value;
  return $html;
}

sub required_string {
  my $self = shift;
  my $html = $self->SUPER::required_string;
     $html =~ s{\A<(\w+)}{<$1 class="pubmed_req"}mxs;
  return $html;
}
sub element_class {
  my $self = shift;
  $self->add_class( '_pubmed' );
  $self->add_class( 'short' );
  $self->add_layout( '_pubmed' );
  return;
}

1;
