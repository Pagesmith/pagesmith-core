package Pagesmith::Utils::Curl::Request;

## Curl request object!
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
use feature qw(switch);

use Const::Fast qw(const);
const my $TIMEOUT      => 30;
const my $SSL_VERSION  => 3;
const my $CONN_TIMEOUT => 5;

use Time::HiRes qw(time);
use WWW::Curl::Easy;

use Pagesmith::Utils::Curl::Response;

use base qw(Pagesmith::Root);

## no critic (CallsToUndeclaredSubs)

sub new {
  my ( $class, $url, $fetcher ) = @_;
  my $resp_class = $fetcher->resp_class;

  my $self = {
    'start_time' => undef,
    'curl_id'    => undef,
    'curl'       => WWW::Curl::Easy->new,
    'url'        => $url,
    'max_size'   => 0,
  };
  bless $self, $class;
  $self->dynamic_use( $resp_class );
  $self->{'response'} = $resp_class->new( $url );

# Initialise the curl object!
  $self->response->set_max_size( defined $fetcher ? $fetcher->max_size : 0 );
  $self->setopt( CURLOPT_HEADERFUNCTION, sub { $_[1]->add_head( $_[0], $self ); return length $_[0]; } );
  $self->setopt( CURLOPT_WRITEFUNCTION,  sub { $self->{'response'}->add_body( $_[0], $self ); return length $_[0]; } );
  $self->setopt( CURLOPT_FILE,           $self->{'response'} );
  $self->setopt( CURLOPT_WRITEHEADER,    $self->{'response'} );
  $self->setopt( CURLOPT_URL,            $self->{'url'} );
  $self->setopt( CURLOPT_USERAGENT,      'PageSmith::Utils::Curl/'.$VERSION );
  $self->setopt( CURLOPT_TIMEOUT,        ( defined $fetcher ? $fetcher->timeout : 0      ) || $TIMEOUT );
  $self->setopt( CURLOPT_CONNECTTIMEOUT, ( defined $fetcher ? $fetcher->conn_timeout : 0 ) || $CONN_TIMEOUT );
  $self->setopt( CURLOPT_SSL_VERIFYHOST, 0 );
  $self->setopt( CURLOPT_SSL_VERIFYPEER, 0 );
  $self->setopt( CURLOPT_SSLVERSION,     $SSL_VERSION );
  $self->set_proxy( $fetcher->proxy ) if defined $fetcher && $fetcher->proxy;

  return $self;
}

sub set_max_size {
  my($self, $max_size ) = @_;
  $self->{'max_size'} = $max_size;
  return $self;
}

sub max_size {
  my $self = shift;
  return $self->{'max_size'};
}

sub set_proxy {
  my( $self, $proxy ) = @_;
  my( $host, $port ) = split m{:}mxs, $proxy;
  return $self unless defined $port;
  $self->setopt( CURLOPT_PROXY,     $host );
  $self->setopt( CURLOPT_PROXYPORT, $port );
  return $self;
}

sub set_timeouts {
  my( $self, $timeout, $conn_timeout ) = @_;
  $self->setopt( CURLOPT_TIMEOUT,        defined $timeout      ? $timeout      : $TIMEOUT      );
  $self->setopt( CURLOPT_CONNECTTIMEOUT, defined $conn_timeout ? $conn_timeout : $CONN_TIMEOUT );
  return $self;
}

sub set_curl_id {
  my ( $self, $curl_id ) = @_;
  $self->{'curl_id'} = $curl_id;
  return $self->{'curl'}->setopt( CURLOPT_PRIVATE, $curl_id ); ##no critic (CallsToUndeclaredSubs)
}

sub set_cookies {
  my( $self, $cookies ) = @_;
  $self->setopt( CURLOPT_COOKIE, join q(; ), @{$cookies} );
  return $self;
}

sub set_headers {
  my( $self, $headers ) = @_;
  $self->setopt( CURLOPT_HTTPHEADER, $headers );
  return $self;
}

sub set_method {
  my( $self, $method ) = @_;
  given( $method ) {
    when ( 'HEAD' ) {
      $self->setopt( CURLOPT_NOBODY,        1 );
      $self->dont_collect;
    }
    when ( 'POST' ) {
      $self->setopt( CURLOPT_POST,    1 );
    }
    when ( 'PUT' ) {
      $self->setopt( CURLOPT_PUT,     1 );
    }
    when ( 'DELETE' ) {
      $self->setopt( CURLOPT_CUSTOMREQUEST,     'DELETE' );
    }
    default {
      $self->setopt( CURLOPT_HTTPGET, 1 );
    }
  }
  return $self;
}

sub dont_collect {
  my $self = shift;
  $self->setopt( CURLOPT_WRITEFUNCTION, sub { $self->{'response'}->add_body_length( $_[0] ); return length $_[0]; } );
  return $self;
}

##use critic

sub setopt {
  my ( $self, $key, $value ) = @_;
  $self->{'curl'}->setopt( $key, $value );
  return $self;
}

sub init {
  my $self = shift;
  $self->{'start_time'} = time;
  return $self;
}

sub curl_id {
  my $self = shift;
  return $self->{'curl_id'};
}

sub curl {
  my $self = shift;
  return $self->{'curl'};
}

sub url {
  my $self = shift;
  return $self->{'url'};
}

sub response {
  my $self = shift;
  return $self->{'response'};
}

sub start_time {
  my $self = shift;
  return $self->{'start_time'};
}

sub response_header {
  my ( $self, $key ) = @_;
  return $self->response->header($key);
}

1;
