package Pagesmith::Component::Zoom;

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

