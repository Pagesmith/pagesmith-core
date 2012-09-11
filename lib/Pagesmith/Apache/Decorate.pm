package Pagesmith::Apache::Decorate;

## Handler to decorate pages
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

use Readonly qw(Readonly);
Readonly my $BUFFER_SIZE => 8192;
Readonly my $MINUTE      => 60;
Readonly my $HOUR        => 60*60;
Readonly my $DAY         => 24*$HOUR;
Readonly my $DOW         => {qw(Mo 1 Tu 2 We 3 Th 4 Fr 5 Sa 6 Su 0)};
Readonly my $WEEK        => 30;
Readonly my $MONTHS      => 12;

use base qw(Apache2::Filter);

use Time::Local qw(timelocal);
use Apache2::Connection  ();
use Apache2::Const qw(OK DECLINED CONN_KEEPALIVE);
use Apache2::RequestRec  ();
use Apache2::RequestUtil ();
use Apache2::URI         ();
use APR::Table           ();
use Crypt::CBC;
use URI::Escape qw(uri_unescape);
use English qw(-no_match_vars $PID);
use File::Basename;
use HTML::Entities qw(encode_entities);
use JSON::XS;
use MIME::Base64 qw(decode_base64);
## use Sys::Hostname;
use Sys::Hostname       qw(hostname);

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Core qw(clean_template_type parse_cookie);
use Pagesmith::Message;
use Pagesmith::Page;

my $templates = {};

#= Defintion of doc types for appropriate HTML/XHTML strict and transitional
my %doctypes = (
  'html:strict'       => '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">',
  'html:transitional' => '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">',
  'xhtml:strict' => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
  'xhtml:transitional' =>
    '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
);


sub _content_type {
  my $r = shift;
  my $accept_header = $r->headers_in->get('Accept') || q();
  return 'text/html; charset=utf-8' unless $accept_header =~ m{xhtml\+xml}mxs;
  my $t = get_config('ContentType');
  return ($t eq 'xhtml' || $t eq 'default' || !$t) ? 'application/xhtml+xml; charset=utf-8' : 'text/html; charset=utf-8';
}

##no critic (ExcessComplexity)
sub handler : FilterRequestHandler {
  my $filter = shift;
  my $r      = $filter->r;
  ## Wrap only HTML files
  if ( $r->content_type !~ m{\A(text/html|application/xhtml\+xml)\b}mxs
    || $r->headers_out->get('X-Pagesmith-Template')||q() eq 'No' ) {
    $filter->remove;    ## Remove the filter so not called multiple times for files we won't handle!
    $r->headers_out->set( 'X-Pagesmith-Debug', sprintf '!%s:%d', hostname, $PID );
    return DECLINED;
  }

  my $ctx = context($filter);
  ## Initialize if first request
  $ctx->{'html'} ||= q() unless $ctx->{'state'};

  ## Only handle 200 HTML at the moment - will need it to wrap
  ## non-redirects later!
  my %handles = map { ( $_ => 1 ) } qw(200 400 401 403 404 405 500 501 502 503);
  return DECLINED unless $handles{ $r->status };

  ## All requests push all HTML
  while ( $filter->read( my $buffer, $BUFFER_SIZE ) ) {
    $ctx->{'html'} .= $buffer;
  }

  $ctx->{'state'}++;

  my $X = $r->err_headers_out;

  ## If last request output HTML...
  my $header;
  if ( $filter->seen_eos ) {
    my $html = $ctx->{'html'};
    ## If the X-Pagesmith-Decor header is set to no do not decorate the page and
    ## just return the raw

    if ( ($r->headers_out->get('X-Pagesmith-Decor')||q()) eq 'no' ) {
      ## Do not decorate this page at all!!!
      ## Even if we don't decorate - we do get the option to cache the
      ## entry here - note don't need to worry about runtime decorate
      ## as there will be no entries at all in this page which need to
      ## be decorated!
      my $key    = $r->headers_out->get('X-Pagesmith-Cache');
      if ($key) {
        my $expiry = $r->headers_out->get('X-Pagesmith-Expiry') || 0;
        Pagesmith::Cache->new( 'page', $key )->set($html, expiry_evaluate( $expiry ) );
      }
    } else {
      ## Create a renderer - to generate output! - note we may not do the template
      ## side of things - but we will in this case do the run time expansion of
      ## <%! !%> entries...
      my $accept_header = $r->headers_in->get('Accept') ||q();
      my $last_mod      = $r->headers_out->get('Last-Modified') || undef;
      my $is_xhr        = $r->headers_in->get('X-Requested-With')||q() eq 'XMLHttpRequest';
      my $template_flag = $r->headers_out->get('X-Pagesmith-Decor') || ( $is_xhr ? 'minimal' : q() );
      my $renderer = Pagesmith::Page->new(
        $r,
        {
          'type'          => $accept_header =~ m{xhtml\+xml}mxs ? 'xhtml' : 'html',
          'last_mod'      => $last_mod,
          'filename'      => $r->filename,
          'uri'           => $r->uri,
          'full_uri'      => $r->construct_url( $r->unparsed_uri ),
          'template_flag' => $template_flag,
          'template_type' => clean_template_type($r),
          'flags'         => parse_cookie($r),
        },
      );
      if( $html =~ m{<!--\sERRORS}mxs ) {
        ## no critic (InterpolationOfMetachars)
        my $cipher = Crypt::CBC->new(
          '-key'    => 'Ru4Aridh0$c4rKur71$5m1?#',
          '-cipher' => 'Blowfish',
          '-header' => 'randomiv', ## Make this compactible with PHP Crypt::CBC
        );
        ## use critic
        my $messages = $r->pnotes( 'errors' );
        while( $html =~ s{<!--\sERRORS\s([=\+\/\w]+)\s-->}{}smx ) {
          my $Z= $cipher->decrypt( decode_base64( $1 ) );
          if( $Z ) {
            my $non_object_data = JSON::XS->new->decode( $Z );
## Replace the following with a json encode!
            push @{$messages}, map { Pagesmith::Message->new_from_hash( $_ ) } @{$non_object_data};
          }
        }
      }

      $r->notes->set( 'html', $html ) if $renderer->developer;

      my $pars = {};
      ## We need to decorate the page and return the templated copy... IF
      ## X-Pagesmith-Decor != 'runtime' which only parses the second stage
      ## directives '<%~ ~%>'
      ( $html, $pars ) = $renderer->decorate($html);

      ## IF the page has a http-equiv X-Pagesmith-Decor no $pars is returned undef
      my $key = $r->headers_out->get('X-Pagesmith-Cache');
      if( $key ) { ## Calling  this too often - need to check we only do it once!!
        #$renderer->minify_html( \$html );
        my $expiry = $pars->{'expiry_time'} || $r->headers_out->get('X-Pagesmith-Expiry') || 0;
        Pagesmith::Cache->new( 'page', $key )->set($html, expiry_evaluate( $expiry ) );
      }
      unless( exists $pars->{'template_flag'} && $pars->{'template_flag'} eq 'no' ) {
        ## Check to see if we have to Cache the rendered page - before we
        ## perform the "runtime" expansion of templates!
        $html = $renderer->runtime_decorate( $html, $pars );
      }
      if( $is_xhr ) {
        $header = q();
      } elsif( $renderer->serve_html ) {
        $html = $renderer->xhtml2html( $html );
        $header = sprintf q(%s<html lang="en-gb">), $doctypes{ 'html:' . get_config('DocType') };
      } else {
        $header = sprintf
          q(<?xml version="1.0" encoding="UTF-8"?>%s<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-gb">),
          $doctypes{ 'xhtml:' . get_config('DocType') };
      }
    }

    ## Remove all X-Pagesmith flags except X-Pagesmith-CacheFlag as this is useful debugging!
    ## We will later add X-Pagesmith-Debug to indicate which request PID this one is!
    foreach my $key (keys %{$r->headers_out} ) {
      next if $key eq 'X-Pagesmith-CacheFlag';
      $r->headers_out->unset( $key ) if $key =~ m{\AX-Pagesmith-}mxs;
    }

    ## Now we have to tidy up the HTML....
    ## Now we have to set the appropriate headers... to make sure that the content
    ## is returned correctly...
    ## Vary tells the caches that it depends on what is accepted!, language says
    ## we are british! and length means that keep-alive works correctly as the
    ## client can know how many bytes to accept!
    $r->headers_out->set(   'Content-Style-Type',  'text/css' );
    $r->headers_out->set(   'Content-Script-Type', 'text/javascript' );
    $r->headers_out->set(   'Vary',                'Accept' );
    $r->headers_out->set(   'Language',            'en-gb' );
    $r->headers_out->set(   'Content-Length',      (length $header) + (length $html) );
    $r->no_cache( 1 );
    ## Set content type to either application/xhtml+xml or text/html
    ## usually we chose the latter as it will break horribly if we have
    ## bad XHTML code!
    $r->content_type( _content_type($r) );
    ## Finally set a Pagesmith-Debug header so that we can see which machine and indeed
    ## Which pid served the file.....


    $r->headers_out->set(   'X-Pagesmith-Debug', sprintf '%s:%d', hostname, $PID );
    ## Last but not least send the html to the next filter (so it can be
    ## deflated!
    $filter->print( $header,$html );

    ## A little bit of tidy up so that the context has no html attached!
    $ctx->{'html'} = q();
  }
  return OK;
}
##use critic (ExcessComplexity)

sub context {
  my ($filter) = shift;
  my $ctx = $filter->ctx;
  unless ($ctx) {
    $ctx = { 'state' => 0, 'keepalives' => $filter->c->keepalives, };
    $filter->ctx($ctx);
    return $ctx;
  }
  my $connection = $filter->c;
  if ( $connection->keepalive == CONN_KEEPALIVE
    && $ctx->{'state'}
    && $connection->keepalives > $ctx->{'keepalives'} ) {
    $ctx->{'state'}      = 0;
    $ctx->{'keepalives'} = $connection->keepalives;
  }
  return $ctx;
}

sub expiry_evaluate {
## Evaluate expiry string
# {\d+}                                     -- expires in 'n' seconds
# {\d+} m|mn|min|minute|ms|mns|mins|minutes -- expires in 'n' minutes
# {\d+} h|hr|hour|hs|hours|hours            -- expires in 'n' hours
# {\d\d:\d\d}                               -- expires at 'hr':'min'
# {\d\d:\d\d} {Mon/Tues/Wed...}             -- expires at 'hr':'min' on next occurance of day
# {\d\d:\d\d} {-\d}                         -- expires at 'hr':'min' on nth day of month
  my $expiry_string = shift;
  if( $expiry_string =~ m{\A(\d+)(?:\s+(min|minute|m|mn|hour|hr|h)s?)?\Z}mxs ) {
    my $expires = 0 - $1;
    my $unit    = $2 || 's';
    $unit = substr $unit,0,1;
    $expires *= $MINUTE if $unit eq 'm';
    $expires *= $HOUR   if $unit eq 'h';
    return $expires;
  }
  if( $expiry_string =~ m{\A(\d\d)(|:\d\d)?(\s+(-?\d+|(?:Mo(?:n)?|Tu(?:es)?|We(?:d(?:nes)?)?|Th(?:u(?:rs)?)?|Fr(?:i)?|Sa(?:t(?:ur)?)?|Su(?:n)?)(?:day)?))?\Z}mxgis ) {
    my( $hr,$mn,$day ) = ($1,$2,$3);
    $mn  = $mn ? substr $mn,1,2 : 0;
    $day ||= q();
    $day =~ s{\s}{}mxsg;
    $day = substr $day,0,2 if $day!~m{\A-?\d+\Z}mxs;

    my $now = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime $now;
    my $expires = $now-$sec+($mn-$min)*$MINUTE+($hr-$hour)*$HOUR;
    if( $expires < $now ) {
      $wday ++;
      $wday %= $WEEK;
      $expires += $DAY;
    }
    if( $day =~ m{\A-?(\d+)\Z}mxs) {
      my $dom = $1;
      ## We now need to get this to from end of month!....
      if( q(-) eq substr $day,0,1 ) {
        $mon++;
        if( $mon>=$MONTHS) {
          $mon = 0;
          $year++;
        }
        $dom = 0 - $dom;
      } else {
        $dom--;
      }
      $expires = timelocal( 0, $mn, $hr, 1, $mon, $year ) + $dom * $DAY;
      if( $expires < $now ) {
        $mon++;
        if( $mon>=$MONTHS) {
          $mon = 0;
          $year++;
        }
        $expires = timelocal( 0, $mn, $hr, 1, $mon, $year ) + $dom * $DAY;
      }
      return $expires;
    }
    return $expires unless( exists $DOW->{(substr $day,0,2)} );
    my $offset = $DOW->{(substr $day,0,2)} - $wday;
       $offset+= $WEEK if $offset < 0;
    return $expires + $offset * $DAY;
  }
  return 0;
}


1;
