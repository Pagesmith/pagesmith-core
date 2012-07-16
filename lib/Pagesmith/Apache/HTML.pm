package Pagesmith::Apache::HTML;

## Apache wrapper for HTML files
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;

use version qw(qv); our $VERSION = qv('0.1.0');

use utf8;

use Pagesmith::Apache::Base qw(_handler);
use Pagesmith::Utils::Tidy;

sub handler {
  my $r = shift;
  return _handler(
    sub {
      my ( $content, $uri, $author ) = @_;
      utf8::decode(${$content}); ##no critic (CallsToUnexportedSubs)
      my $t = Pagesmith::Utils::Tidy->new(1);
      my $x = $t->tidy($content);
      return $x;
    },
    $r,
  );
}

1;
