package Pagesmith::Component::Zoom;

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

## Used to set zoom level in body tag
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
  my $self = shift;
  return {
    'parameters'  => q(none),
    'description' => 'Inserts an extra class tag into the body to change the zoom level...',
    'notes'       => [],
  };
}

sub execute {

#@param (self)
#@return (html) class attribute string containing zoom_level class
## Simply grabs the zoom_level from the users cookie and returns the
## HTML fragment to set the approriate class on the page

  my $self = shift;
  return sprintf ' class="s-%s"', $self->page->zoom_level;
}

1;

__END__

h3. Syntax

<% Zoom
%>

h3. Purpose

Set the class on the body to set the Zoom level according to the zoom level cookie information

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

