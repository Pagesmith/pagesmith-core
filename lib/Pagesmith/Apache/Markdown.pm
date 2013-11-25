package Pagesmith::Apache::Markdown;

## Apache handler for markdown format code
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

use Text::MultiMarkdown;

use Pagesmith::Apache::Base qw(my_handler expand_content);

sub handler {
  my $r = shift;
  return my_handler(
    sub {
      my ( $content, $uri, $author ) = @_;

      my $m    = Text::MultiMarkdown->new( 'heading_ids' => 0, 'img_ids' => 0 );
      my $html = $m->markdown(${$content});

      return expand_content( \$html, $html =~ m{<(h\d)>(.*)</\1>}mxs ? $2 : $uri, $author );
    },
    $r,
  );
}

1;
