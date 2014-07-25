package Pagesmith::Component::DbInc;

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

use base qw(Pagesmith::Component);

sub usage {
  return (
    'parameters'  => 'key',
    'description' => 'Returns a valid XHTML fragment from the database',
    'notes'       => [],
  );
}

sub execute {
  my $self = shift;

  my $msg = $self->get_adaptor( 'DbInc' )->get_message( $self->next_par );
  return '<span class="web-error">Unknown message code</span>' unless defined $msg;
  return $msg;
}

1;

__END__

h3. Syntax

<% Qr %>

h3. Purpose

Insert a QR image and link into the top right of the page

h3. Options

None

h3. Notes

An automatically generated Qr code is given to the page IF the URL is not already in the Qr database - note if you
want a specific QR code for a page you can manually insert this into the QR table

h3. See also

* Pagesmith::Adaptor::Qr

* Pagesmith::Action::Qr

h3. Examples

None

h3. Developer notes

See Adaptor module for information about the qr image generation code and the database schema
