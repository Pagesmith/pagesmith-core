package Pagesmith::Apache::Text;

## mod_perl Apache Responser Handler which grabs a plain
## text file and wraps in HTML tags so that it will get
## picked up by the Output Filter.

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

use HTML::Entities qw(encode_entities);

use Pagesmith::Apache::Base qw(my_handler expand_content);

sub handler {
  my $r = shift;
  return my_handler(
    sub {
      my ( $content, $uri, $author ) = @_;

      my $html = '<pre>' . encode_entities(${$content}) . '</pre>';

      return expand_content( \$html, $uri, $author );
    },
    $r,
  );
}

1;
