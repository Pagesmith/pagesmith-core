package Pagesmith::Utils::Curl::Request;

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
  $self->response->set_max_size_action( defined $fetcher ? $fetcher->max_size_action : 'truncate' );
  $self->setopt( CURLOPT_HEADERFUNCTION, sub { $_[1]->add_head( $_[0], $self ); return length $_[0]; } );
  $self->setopt( CURLOPT_WRITEFUNCTION,  sub { $self->{'response'}->add_body( $_[0], $self ); return length $_[0]; } );
  $self->setopt( CURLOPT_FILE,           $self->{'response'} );
  $self->setopt( CURLOPT_WRITEHEADER,    $self->{'response'} );
  $self->setopt( CURLOPT_URL,            $self->{'url'} );
  $self->setopt( CURLOPT_USERAGENT,      'Pagesmith::Utils::Curl/'.$VERSION );
  $self->setopt( CURLOPT_TIMEOUT,        ( defined $fetcher ? $fetcher->timeout : 0      ) || $TIMEOUT );
  $self->setopt( CURLOPT_CONNECTTIMEOUT, ( defined $fetcher ? $fetcher->conn_timeout : 0 ) || $CONN_TIMEOUT );
  $self->setopt( CURLOPT_SSL_VERIFYHOST, 0 );
  $self->setopt( CURLOPT_SSL_VERIFYPEER, 0 );
  $self->setopt( CURLOPT_SSLVERSION,     $SSL_VERSION );
  $self->setup_proxy( $fetcher->proxy, $fetcher->no_proxy, $url ) if defined $fetcher;

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

sub setup_proxy {
  my( $self, $proxy, $no_proxy, $url ) = @_;
  if( $proxy ) {
    my $use_proxy = 1;
    my $host_name = $url =~ m{\Ahttps?://([^/]+)}mxs ? $1 : q();
    foreach my $rule ( @{$no_proxy} ) {
      $rule =~ s{,\s*\Z}{}mxs;
      if( q(.) eq substr $rule,0,1 ) {
        $use_proxy = 0 if $rule eq substr $host_name, -length $rule;
      } else {
        $use_proxy = 0 if $host_name eq $rule;
      }
    }
    if( $use_proxy ) {
      $proxy =~ s{\Ahttps?://}{}mxs;
      my( $host, $port ) = split m{:}mxs, $proxy;
      $port =~ s{\D}{}mxsg;
      if( $port ) {
        $self->setopt( CURLOPT_PROXY,     $host );
        $self->setopt( CURLOPT_PROXYPORT, $port );
      }
      return $self;
    }
  }
  $self->setopt( CURLOPT_PROXY,     q() );
  return $self;
}

sub set_no_proxy {
  my( $self, $no_proxy ) = @_;
  $self->setopt( CURLOPT_NOPROXY, join q(, ), @{$no_proxy} );

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
  $self->dont_collect if $method eq 'HEAD';
  if( $method eq 'DELETE' ) {
    $self->setopt( CURLOPT_CUSTOMREQUEST,     'DELETE' );
  } else {
    $self->setopt( $method eq 'HEAD' ? CURLOPT_NOBODY
                 : $method eq 'POST' ? CURLOPT_POST
                 : $method eq 'PUT'  ? CURLOPT_PUT
                 :                     CURLOPT_HTTPGET, 1 );
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
