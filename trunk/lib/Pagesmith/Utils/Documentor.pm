package Pagesmith::Utils::Documentor;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

## base class for documentor code - really just deals with markdown!
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

sub markdown_html {
#@params (self) (string lines)+
#@return (string) HTML markup
## returns a marked up version of the HTML.
##
## this is modified to format nicely with Pagesmith - including fixing heading levels (so == => h3 & -- => h4)

  my( $self, $lines ) = @_;
  my $t    = join q(),@{$lines};
  return unless $t;
  my $m    = Text::MultiMarkdown->new( 'heading_ids' => 0, 'img_ids' => 0 );
  my $html = $m->markdown( $t );

  $html =~ s{<h([12])(.*?</h)\1>}{'<h'.($1+2).$2.($1+2).'>'}mxseg;
  $html =~ s{<h3}{<h3 class="keep"}mxsg;
  $html =~ s{<table}{<table class="zebra-table"}mxsg;
  $html =~ s{\s+align="(right|left|center)"}{' class="'.(substr $1,0,1).'"'}mxseg;
  $html = "<p>$html</p>" unless $html =~ m{\A<}mxsg;
  return $html;
}

1;
