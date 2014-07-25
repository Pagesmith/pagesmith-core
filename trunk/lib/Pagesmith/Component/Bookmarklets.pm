package Pagesmith::Component::Bookmarklets;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Component);
use HTML::Entities qw(encode_entities);

sub usage {
  return {
    'parameters'  => q({domain}+),
    'description' => 'Generates a block of links which can be used to flip the browser between sandbox/dev/staging/live sites',
    'notes'       => [ 'If "THIS" is in the list - generates a sandbox for this domain - usually this will be the sandbox' ],
  };
}

sub execute {
  my $self = shift;
  my @domains = $self->pars;
# No restriction so return!
  my @links;
  foreach my $domain ( @domains ) {
    $domain = $self->r->hostname if $domain eq 'THIS';
    ( my $name = $domain ) =~ s{[.]([-\w]+)[].ac[.]uk}{}mxs;
    push @links, sprintf q(  <li><a href="javascript:(function() {window.location.href=window.location.toString().replace(/^http:\/\/([^\/]+)/,'http://%s');})()">%s</a></li>),
      $domain, $name;
  }
  return sprintf qq(<ul>\n%s\n</ul>), join qq(\n), @links;
}
1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

