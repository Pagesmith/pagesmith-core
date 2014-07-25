package Pagesmith::Action::Das::DSN;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

## Monitorus proxy!
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-13
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action::Das);
use Const::Fast qw(const);
const my $VALID_REQUEST => 200;

sub run {
  my $self = shift;
  $self->r->headers_out->set( 'X-Das-Capabilities', 'sources/1.0; dsn/1.0' );
  $self->r->headers_out->set( 'X-DAS-Status',       $VALID_REQUEST );
  my $markup = sprintf
    qq(<?xml version="1.0" encoding="UTF-8" ?>\n<?xml-stylesheet type="text/xsl" href="/core/css/das.xsl"?>\n<DASDSN>%s</DASDSN>),
    join q(),
    map { $_->{'dsn_doc'} }
    $self->filtered_sources;
  return $self->xml->set_length( length $markup )->print( $markup )->ok;
}


1;
