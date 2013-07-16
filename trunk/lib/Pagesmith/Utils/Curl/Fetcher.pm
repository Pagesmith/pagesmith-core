package Pagesmith::Utils::Curl::Fetcher;

## Curl Fetch - does a (multi) Curl fetch!
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

use WWW::Curl::Multi;

use Pagesmith::Utils::Curl::Request;

use Data::Dumper qw(Dumper);

sub new {
  my $class = shift;
  my $self  = {
    'active_handles' => 0,
    'curl_id'        => 1,
    'resp_class'     => 'Pagesmith::Utils::Curl::Response',
    'data'           => {},
    'curlm'          => WWW::Curl::Multi->new(),
    'proxy'          => undef,
    'timeout'        => 0,
    'conn_timeout'   => 0,
    'max_size'       => 0,
  };
  bless $self, $class;
  return $self;
}

sub set_resp_class {
  my( $self, $val ) = @_;
  $self->{'resp_class'} = $val;
  return $self;
}

sub resp_class {
  my $self = shift;
  return $self->{'resp_class'};
}

sub set_max_size {
  my( $self, $val ) = @_;
  $self->{'max_size'} = $val;
  return $self;
}

sub max_size {
  my $self = shift;
  return $self->{'max_size'};
}

sub set_timeout {
  my( $self, $val ) = @_;
  $self->{'timeout'} = $val;
  return $self;
}

sub set_conn_timeout {
  my( $self, $val ) = @_;
  $self->{'conn_timeout'} = $val;
  return $self;
}

sub timeout {
  my $self = shift;
  return $self->{'timeout'};
}

sub conn_timeout {
  my $self = shift;
  return $self->{'conn_timeout'};
}

sub new_request {
  my( $self, $url, $method ) = @_;
  my $t = Pagesmith::Utils::Curl::Request->new( $url, $self );
  $t->set_method( defined $method ? $method : 'GET' );
  $t->init;
  $self->add( $t );
  return $t;
}

sub active_handles {
  my $self = shift;
  return $self->{'active_handles'};
}

sub active_transfers {
  my $self = shift;
  return $self->{'curlm'}->perform;
}

sub new_responses {
  my $self = shift;
  return $self->active_transfers - $self->active_handles;
}
sub has_active {
  my $self = shift;
  return $self->{'active_handles'} > 0;
}

sub proxy {
  my $self = shift;
  return $self->{'proxy'};
}

sub set_proxy {
  my( $self, $proxy ) = @_;
  $self->{'proxy'} = $proxy;
  return $self;
}

sub remove {
  my $self = shift;
  my $req  = shift;
  ## The request id isn't present --- argh!
  return 0 unless $self->{'data'}{ $req->curl_id };
  $self->{'curlm'}->remove_handle( $req->curl );
  $self->{'active_handles'}--;
  delete $self->{'data'}{ $req->curl_id };
  undef $req->{'curl'}; ## Remove the curl object o/w garbage collection won't happen!
  return $req->curl_id;
}

sub next_request {
  my $self = shift;
  my ( $id, $return_value ) = $self->{'curlm'}->info_read;
  return unless $id;
  my $t = $self->{'data'}{$id};
  $t->{'return_value'} = $return_value;
  return $t;
}

sub add {
  my ( $self, $req ) = @_;
  ## The request id is present --- argh!
  return 0 if exists $self->{'data'}{ $self->{'curl_id'} };
  $req->set_curl_id( $self->{'curl_id'}++ );
  $self->{'data'}{ $req->curl_id } = $req;
  $self->{'curlm'}->add_handle( $req->curl );
  $self->{'active_handles'}++;
  return 1;
}

1;
