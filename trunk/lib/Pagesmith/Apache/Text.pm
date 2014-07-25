package Pagesmith::Apache::Text;

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
