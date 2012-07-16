package Pagesmith::Component::ShareWith;

## Component - which generates the shared with URLS....
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

sub _cache_key {
  my $self = shift;
  return 1;
}

sub execute {
  my $self   = shift;
  my $output = '<ul>';
  my @links  = ( [
      'email' => 'Email this',
      'mailto:?subject=<%= u:title %>&amp;body='
        . $self->url_encode("I found this and thought it might be of interest to you:\r\r   ")
        . '<%= u:full_uri %>'
        . $self->url_encode("\r\r") ],
    ['digg'     => 'Digg this',         'http://digg.com/submit?phase=2&amp;url=<%= u:full_uri %>&amp;title=<%= u:title %>'],
    ['facebook' => 'Share on Facebook', 'http://www.facebook.com/sharer.php?u=<%= u:full_uri %>&amp;t=<%= u:title %>'],
    [
      'delicious' => 'Add to Del.icio.us',
      'http://del.icio.us/post?v=4&amp;noui=yes&amp;jump=close&amp;url=<%= u:full_uri %>&amp;title=<%= u:title %>' ],
    [
      'slashdot' => 'Slashdot it',
      'http://slashdot.org/submit.pl?url=<%= u:full_uri %>;mediatype=text;subj=<%= u:title %>;primaryskid=14;tid=350;' ],
    ['reddit'  => 'Add to reddit', 'http://www.reddit.com/submit?url=<%= u:full_uri %>;title=<%= u:title %>'],
    ['twitter' => 'Tweet',         'http://twitter.com/home?status=<%= u:title %>%20(%20<%= u:full_uri %>%20)'],
    ['stumble' => 'Stumble upon',  'http://www.stumbleupon.com/submit?url=<%= u:full_uri %>;title=<%= u:title %>'],
  );
  foreach my $link_ref (@links) {
    $output .= sprintf '<li class="linkto l_%s"><a href="%s" %s>%s</a></li>',
      $link_ref->[0],
      $link_ref->[2],
      $link_ref->[2] =~ m{\Ahttp}mxs ? 'class="no-img" ' : q(),
      $self->encode( $link_ref->[1] );
  }
  $output .= '</ul>';
  return $output;
}

1;

__END__

h3. Deprecated

h3. Syntax

<% ShareWith
%>

h3. Purpose

Create links to allow the page to be linked to from various social networking sites
h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

