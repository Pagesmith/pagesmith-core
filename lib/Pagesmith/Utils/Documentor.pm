package Pagesmith::Utils::Documentor;

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
  my $m    = Text::MultiMarkdown->new( 'heading_ids' => 0, 'img_ids' => 0 );
  my $html = $m->markdown( join q(),@{$lines} );

  $html =~ s{<h([12])(.*?</h)\1>}{'<h'.($1+2).$2.($1+2).'>'}mxseg;
  $html =~ s{<h3}{<h3 class="keep"}mxsg;
  $html =~ s{\s+align="(right|left|center)"}{' class="'.(substr $1,0,1).'"'}mxseg;
  return $html;
}

1;
