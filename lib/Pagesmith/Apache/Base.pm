package Pagesmith::Apache::Base;

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

use base qw(Exporter);

use Apache2::Const qw(M_OPTIONS DECLINED HTTP_METHOD_NOT_ALLOWED M_GET DECLINED FORBIDDEN NOT_FOUND OK);
use Apache2::RequestIO;
use Apache2::RequestUtil;
use Apache2::RequestRec;
use APR::Table;
use APR::Finfo;
use Date::Format qw(time2str);
use HTML::Entities qw(encode_entities);
use Time::HiRes qw(time);

use Pagesmith::Apache::Decorate;
use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(can_cache get_config);
use Pagesmith::Core qw(safe_md5 parse_cookie clean_template_type);

our @EXPORT_OK = qw(my_handler expand_content);
our %EXPORT_TAGS = ('ALL' => \@EXPORT_OK);


sub expand_content {
## Used by helper functions - just an HTML wrapper that sets the author and
## title for text based files...
  my ( $html, $title, $author ) = @_;
  my $t = sprintf qq(<html>\n<head>\n  <meta name="author" content="%s" />\n  <title>%s</title>\n</head>\n<body>\n%s\n</body>),
    encode_entities( $author ),
    encode_entities( $title ),
    ${$html};
  return \$t;
}

sub my_handler {

## Base handler ... called by handler functions in derived classes, takes
## a callback function which manipulates the contents of the file and the
## apache handler... returns status code and if valid sends (undecorated)
## HTML to the next stage!

##no critic (CommentedOutCode)
#  my $t = time;
#  my $ret = __handler(@_);
#  $t = time-$t;
#  warn "$$ HTML handler - time taken $t\n";
#  return $ret;
#}
##use critic (CommentedOutCode)
#
#sub __handler {
  my ( $callback, $r ) = @_;

  ## Look for things we don't do!
  return DECLINED if $r->method_number == M_OPTIONS;
  return HTTP_METHOD_NOT_ALLOWED unless $r->method_number == M_GET;

  ## Do we cache pages.. if we do set the appropriate heading AND
  ## grab the file from the cache if it is there!!!

  if ( can_cache('pages') ) {
    my ( $uri, $qs ) = split m{[?]}mxs, $r->unparsed_uri, 2;
    $uri =~ s{/index[.]html\Z}{/}mxs;    ## Remove the trailing index.html
    $uri =~ s{[/|]}{=}mxgs;                ## Replace / with =..
    my $flags     = parse_cookie($r);
    my $flush_cache = ( ($r->headers_in->{'Cache-Control'}||q()) =~ m{max-age=0}mxs || ($r->headers_in->{'Pragma'}||q()) eq 'no-cache' )
      && $r->method ne 'POST';
    my $cache_key  = sprintf '%s-%s|%s|%s',
      $flags->{'a'} && $flags->{'a'} eq 'e' ? 'e' : 'd',
      clean_template_type($r),
      $uri,
      get_config( 'CachePageParams' ) eq 'true' && defined $qs ? safe_md5($qs) : q(-);

    my $l_html;
    my $ch = Pagesmith::Cache->new( 'page', $cache_key );
    if( $flush_cache ) {
      $r->headers_out->set( 'X-Pagesmith-CacheFlag', 'flush' );
      my $other_cache = (('d' eq substr $cache_key, 0, 1)?'e':'d').substr $cache_key,1;
      $other_cache = Pagesmith::Cache->new( 'page', $cache_key );
      $other_cache->unset;
    } else {
      $l_html = $ch->get();
      if ( defined $l_html ) {
        ## We have retrieved the HTML from the cache - so we need to
        ## set the headers so that we re-parse the file at runtime!
        ## this expands out any <%~ ~%> directives.
        ## but don't have to do anything else
        $r->content_type('text/html');
        $r->headers_out->set( 'X-Pagesmith-Decor', 'runtime' );
        $r->headers_out->set( 'Content-Length', length $l_html );
        ## and print the HTML.
        $r->headers_out->set( 'X-Pagesmith-CacheFlag', 'hit' );
        $r->add_output_filter( \&Pagesmith::Apache::Decorate::handler ); ## no critic (CallsToUnexportedSubs)
        $r->print($l_html);
        return OK;
      } else {
        $r->headers_out->set( 'X-Pagesmith-CacheFlag', 'miss' );
      }
    }
    $r->headers_out->set( 'X-Pagesmith-Cache', $cache_key );
  }
  ## Now we check to see if exists on the filesystem! and if it does - slurp it in,
  ## Set a last modified header!
  return DECLINED  if     -d $r->filename;    # decline directories
  return NOT_FOUND unless -e $r->filename;    # not-found unless it exists
  return FORBIDDEN unless -r $r->filename;    # forbidden if we can't read it!

  my ($author_id,$u_passwd,$u_uid,$u_gid,$u_quota,$u_comment,$author_name,$u_dir,$u_shell,$u_expire) = getpwuid $r->finfo->user;
  $author_name =~ s{,,+\s*}{}mxs;
  my $html = &{$callback}(
    $r->slurp_filename,                       ## scalar ref to contents of file!
    $r->uri,                                  ## URI of page...
    sprintf '%s (%s)', $author_name, $author_id,  ## Author as "Name (username)"
  );
  $r->headers_out->set( 'Last-modified', time2str( '%a, %d %b %Y %H:%M:%S %Z', $r->finfo->mtime, 'GMT' ) );
  ## Set appropriate headers...
  ##   content/type (so that the subsequent filter will handle output)
  ##   content length
  $r->content_type(     'text/html' );
  $r->headers_out->set( 'Content-Length', length ${$html} );
  $r->add_output_filter( \&Pagesmith::Apache::Decorate::handler ); ## no critic (CallsToUnexportedSubs)
  $r->print(${$html});
  return OK;
}

1;
