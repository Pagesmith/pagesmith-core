package Pagesmith::Form::Element::Heading;

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

sub validate {
  my $self = shift;
  return $self->set_valid;
}
sub init {
  my $self = shift;
  return;
}

sub is_input {
  my $self = shift;
  return 0;
}

sub is_required {
  my $self = shift;
  return 0;
}

sub render {
  my $self = shift;
  return sprintf qq(\n  </dl>\n  <h4 class="clear">%s</h4>\n  <dl>),
    encode_entities($self->caption)
  ;
}

sub render_readonly {
  my $self = shift;
  return sprintf qq(\n  </dl>\n  <h4 class="clear">%s</h4>\n  <dl class="twocol">),
    encode_entities($self->caption)
  ;
}

sub render_paper {
  my $self = shift;
  return $self->render_readonly;
}

1;
