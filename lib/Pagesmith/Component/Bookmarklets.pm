package Pagesmith::Component::Bookmarklets;

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

sub execute {
  my $self = shift;
  my @domains = $self->pars;
# No restriction so return!
  my @links;
  foreach my $domain ( @domains ) {
    $domain = $self->r->hostname if $domain eq 'THIS';
    ( my $name = $domain ) =~ s{\.([-\w]+)\.ac\.uk}{}mxs;
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

