package Pagesmith::Apache::SHTML;

## Apache wrapper for SHTML files..
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

use utf8;

use Pagesmith::Apache::Base qw(my_handler);
use Pagesmith::Utils::Tidy;
use Pagesmith::Utils::SHTML;

sub handler {
  my $r = shift;
  return my_handler(
    sub {
      my ( $content, $uri, $author ) = @_;
      utf8::decode(${$content}); ##no critic (CallsToUnexportedSubs)
      my $t = Pagesmith::Utils::SHTML->new(1);
      my $a = $t->parse($content);
      my $u = Pagesmith::Utils::Tidy->new(1);
      my $x = $u->tidy($a);
      return $x;
    },
    $r,
  );
}

1;
