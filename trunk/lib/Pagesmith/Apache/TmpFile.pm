package Pagesmith::Apache::TmpFile;

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

## mod_perl Apache Responser Handler base class which uses a number of different formatters..
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

use Const::Fast qw(const);
const my $ONE_MONTH => 2_592_000;
const my $ONE_YEAR => 31_622_400;
const my %MIME_TYPE_MAP => qw(
  css  text/css;charset=utf-8
  js   text/javascript;charset=utf-8
  gif  image/gif
  pdf  application/pdf
  png  image/png
  jpg  image/jpeg
  jpeg image/jpeg
  map  application/json
);
const my $DEFAULT_MIME_TYPE => 'text/html;charset=utf-8';

use Apache2::Const qw(OK FORBIDDEN DECLINED HTTP_METHOD_NOT_ALLOWED NOT_FOUND M_OPTIONS M_GET);
use Apache2::RequestIO;
use Apache2::RequestUtil;
use APR::Table;
use APR::Finfo;
use Apache2::Util qw(ht_time);
use HTML::Entities qw(encode_entities);
use Date::Format qw(time2str);
use Time::HiRes qw(time);

use Pagesmith::ConfigHash qw(get_config site_key);
use Pagesmith::Apache::Action;
use Pagesmith::Cache;

sub handler {
  my $r       = shift;
  my $t       = time;
  my $tmp_url = q(^) . quotemeta( get_config('TmpUrl') || '/t/' ) . '(.*?)/(.*?)$';
  my $uri     = $r->uri;
  if ( $uri =~ m{$tmp_url}mxs ) {
    ## push the handler...
    $r->handler('modperl');
    $r->notes->set( 'filename' => "$1|$2" );
    ## If the URL is a c.js (compressed javascript then we can create a source map header!)
    if( $uri =~ m{(.*)[.]c[.]js\Z}mxs ) {
      $r->headers_out->set('X-SourceMap',"$1.js.map");
    }
    $r->filename( $tmp_url );
    $r->push_handlers( 'PerlResponseHandler' => \&send_content );
    return OK;
  } elsif ( $uri =~ m{(?:/[.]svn/|/CVS/)}mxs ) {
    return FORBIDDEN;
  } elsif ( $uri =~ m{\A/(?:action|form|go|qr|error|login|logout|component)/}mxs ||
            $uri =~ m{\A/(?:action|go|qr|error|login|logout|component)\Z}mxs ) {
    $r->handler('modperl');
    $r->push_handlers( 'PerlResponseHanlder'     => \&Pagesmith::Apache::Action::handler ); ## no critic (CallsToUnexportedSubs)
    $r->push_handlers( 'PerlMapToStorageHandler' => sub { return OK; } );
  }
  return DECLINED;
}

sub send_content {
## Base handler ... called by handler functions in derived classes, takes
## a callback function which manipulates the contents of the file and the
## apache handler... returns status code and if valid sends (undecorated)
## HTML to the next stage!
  my $r = shift;
  my $t = time;
  ## Look for things we don't do!
  return DECLINED                if $r->method_number == M_OPTIONS;
  return HTTP_METHOD_NOT_ALLOWED if $r->method_number != M_GET;
## We are going to serve static content from memcached if is there!
  ( my $filename = $r->notes->get('filename') ) =~ s{[^-|\w.]}{}mxgs;

## Create a new Cache file!

  my @sites = (site_key);
  my $site_alt = get_config( 'AltCacheSite' );
  push @sites, $site_alt if $site_alt;
  foreach my $site ( @sites ) {
    my $ch = Pagesmith::Cache->new( 'tmpfile', $filename, undef, $site );
    my $content = $ch->get();

    if ($content) {
      my ($extn) = $filename =~ m{[.](\w+)\Z}mxs;
      $r->content_type(     exists $MIME_TYPE_MAP{$extn} ? $MIME_TYPE_MAP{$extn} : $DEFAULT_MIME_TYPE );
      $r->headers_out->set( 'Content-Length', length $content );
      $r->headers_out->set( 'Last-Modified',  Apache2::Util::ht_time( $r->pool, time - $ONE_MONTH ) ); ## no critic(CallsToUnexportedSubs)
      $r->headers_out->set( 'Expires',        Apache2::Util::ht_time( $r->pool, time + $ONE_YEAR  ) ); ## no critic(CallsToUnexportedSubs)
      $r->headers_out->set( 'Cache-Control',  "max-age=$ONE_YEAR,public" );
      $r->print($content);
      return OK;
    }
  }
  return NOT_FOUND;
}

1;
