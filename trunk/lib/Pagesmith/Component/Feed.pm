package Pagesmith::Component::Feed;


## Package to handle RSS feeds
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

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(),
    'description' => 'To display an RSS feed - currently removed!',
    'notes'       => [],
  };
}

1;

__END__
use Readonly qw(Readonly);
Readonly my $MAX_FEEDS    => 5;
Readonly my $EXPIRY       => 300;
Readonly my $FEED_TIMEOUT => 10;
Readonly my $DEF_CODE     => 999;

use base qw(Pagesmith::Component);

use HTML::Entities qw(encode_entities);
use HTTP::Request;
use LWP::Parallel::UserAgent;
use XML::Feed;

use Pagesmith::Cache qw(get set);
use Pagesmith::ConfigHash qw(get_config can_cache proxy_url);
use Pagesmith::Core qw(safe_md5);
use Pagesmith::Utils::Tidy;

sub ajax {
## This component can be loaded via AJAX rather than
## embedded in the page if the browser supports it!
  return 1;
}

sub my_cache_key {
## This component can be cached to memcached/sql/disk cache
## - just cache based on the given parameters...
  my $self = shift;
  return $self->checksum_parameters();
}

sub cache_expiry {
## This component can only be cached for 5 minutes
  return $EXPIRY;    ## Time in seconds.
}

sub _parse_feed {
  my $self    = shift;
  my $xml_ref = shift;
  my $feed    = XML::Feed->parse($xml_ref);
  return $feed;
}

sub _fetch_xml {
  my $self = shift;
  my $xml  = {};
  my @reqs = ();
  foreach ( $self->pars ) {
    my $entry =
        can_cache('feeds')
      ? get( $self->{'cache_key'} )
      : undef;
    if ($entry) {
      $xml->{ $_->{'url'} } = $entry;
    } else {
      push @reqs, HTTP::Request->new( 'GET' => $_->{'url'} );
      $xml->{ $_->{'url'} } = { 'title' => $_->{'title'}, 'content' => q(), 'status' => 'timeout', 'code' => $DEF_CODE, 'ok' => 0 };
    }
  }
  if (@reqs) {
    my $ua = LWP::Parallel::UserAgent->new();
    $ua->max_hosts( $MAX_FEEDS );
    $ua->max_req(   $MAX_FEEDS );
    $ua->proxy( [qw(http https)], proxy_url() );
    $ua->agent('Pagesmith::Component::Feed');
    $ua->register($_) foreach @reqs;
    my $reqs = $ua->wait( get_config('Feed_Timeout') || $FEED_TIMEOUT );
    foreach ( keys %{$reqs} ) {
      my $res = $reqs->{$_}->response;
      my $u   = $res->request->url;
      $xml->{$u}{'content'} = $res->content;
      $xml->{$u}{'status'}  = $res->message;
      $xml->{$u}{'code'}    = $res->code;
      $xml->{$u}{'ok'}      = $res->is_success;
    }
  }
  return $xml;
}

sub _format_feed {
  my( $self, $tmp_ref ) = @_;
  my $feed    = $self->_parse_feed($tmp_ref);
  unless ($feed) {
    return sprintf "\n  <h3>%s</h3>\n  <p>Unable to retrieve feed</p>", encode_entities( $_->{'title'} );
  }
  my $feed_html = sprintf qq(\n  <h3><a rel="external" href="%s">%s</a></h3>), $feed->link, encode_entities( $feed->title );
  if ( $feed->tagline ) {
    $feed_html .= '<h4><em>' . $feed->tagline . '</em></h4>';
  }
  if ( $feed->description && $feed->tagline ne $feed->description ) {
    my $desc = $feed->description;
    $feed_html .= ${ $self->{'tidy'}->fragment( \$desc ) };
  }
  if ( $feed->entries ) {
    $feed_html .= qq(\n  <ul class="feed">);
    foreach ( $feed->entries ) {
      my $desc = $_->summary->body || $_->content->body;
      if ($desc) {
        $feed_html .= sprintf qq(\n      <li><a rel="external" href="%s">%s</a><div class="feed_tog">%s</div></li>),
          $_->link,
          $_->title,
          ${ $self->{'tidy'}->fragment( \$desc ) };
      } else {
        $feed_html .= sprintf qq(\n      <li><a rel="external" href="%s">%s</a></li>), $_->link, $_->title;
      }
    }
    $feed_html .= '  </ul>';
  } else {
    $feed_html .= '  <p>There are no entries in this feed</p>';
  }
  $feed_html .= sprintf qq(\n  <p>Feed last updated: %s</p>), $feed->modified;

  return $feed_html;
}

sub execute {
  my( $self, @pars ) = @_;

  $self->{'tidy'} = Pagesmith::Utils::Tidy->new();

  my @feeds = ();
  while ( my ( $url, $title ) = splice @pars, 0, 2 ) {
    push @feeds, { 'url' => $url, 'title' => $title || $url, 'cache_key' => 'feed|' . safe_md5($url) };
  }
  my $sources = $self->_fetch_xml(@feeds);

  my $html;
  foreach (@feeds) {
    my $xml_blob = $sources->{ $_->{'url'} };
    unless ( $xml_blob->{'parsed'} ) {
      my $t = $xml_blob->{'content'};
      $xml_blob->{'parsed'} = $self->_format_feed( \$t );
      delete $xml_blob->{'content'};
      set( $_->{'cache_key'}, $xml_blob, $EXPIRY ) if can_cache('feeds');    ## Expire in 5 minutes!
    }

    $html .= $xml_blob->{'parsed'};
  }
  return $html;
}

1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

