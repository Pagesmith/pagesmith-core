package Pagesmith::Utils::Curl::Response;

## Curl response object wrapper!
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

const my $MAX_SIZE => 1 << 30;
#-------------------------------------------------------------------------------
## Class to store response from a Curl request
## Two functions "add_head" and "add_body" parse the response and
## populate the body and head of this object.
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Initializer
#-------------------------------------------------------------------------------

sub new {
  my ($class,$url) = @_;
  my $self = {
    'headers'      => {},
    'code'         => 0,
    'text'         => undef,
    'http_version' => 0,
    'body'         => [],
    'max_size'     => $MAX_SIZE,
    'size'         => 0,
    'url'          => $url,
  };
  bless $self, $class;
  return $self;
}

#-------------------------------------------------------------------------------
# Accessors
#-------------------------------------------------------------------------------

sub set_max_size {
  my( $self, $size ) = @_;
  $self->{'max_size'} = $size;
  return $self;
}

sub max_size {
  my $self = shift;
  return $self->{'max_size'} || $MAX_SIZE;
}
sub http_version {
  my $self = shift;
  return $self->{'http_version'};
}

sub code {
  my $self = shift;
  return $self->{'code'};
}

sub text {
  my $self = shift;
  return $self->{'text'};
}

## accessor for the body of the response
sub body {
  my $self = shift;
  return join q(), @{ $self->{'body'} };
}

sub size {
  my $self = shift;
  return $self->{'size'};
}

## accessors for the head of the request
sub header {
  my( $self,$key ) = @_;
  $key  = lc $key;
  return unless exists $self->{'headers'}{$key};
  return wantarray() ? @{ $self->{'headers'}{$key} } : $self->{'headers'}{$key}[-1];
}

sub content_length {
  my $self = shift;
  return $self->header('content-length') || 0;
}

#-------------------------------------------------------------------------------
# Parsing functions!
#-------------------------------------------------------------------------------
sub add_body {
  my ( $self, $chunk ) = @_;
  push @{ $self->{'body'} }, $chunk if $self->{'size'} < $self->max_size;
  $self->{'size'} += length $chunk;
  if( $self->{'size'} > $self->max_size ) {
    $self->{'body'} = [];
  }
  return;
}

sub add_body_length {
  my ( $self, $chunk ) = @_;
  $self->{'size'} += length $chunk;
  return;
}

sub add_head {
  my ( $self, $chunk ) = @_;
  chomp $chunk;
  $chunk =~ s{\s+\Z}{}mxs;    ## Remove trailing whitespace.
  if ( $chunk =~ m{\AHTTP/(\d[.]d)\s*(\d+)\s*(.*)}mxs ) {    ## Handle the HTTP line
    $self->{'http_version'} = $1;
    $self->{'code'}         = $2;
    $self->{'text'}         = $3;
  } elsif ( $chunk =~ m{\A(.*?):\s*(.*)}mxs ) {              ## Handle all other header lines
    my $key = lc $1;
    push @{ $self->{'headers'}{ $key } }, $2;
  }
  return;
}

1;
