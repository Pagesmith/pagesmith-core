package Pagesmith::Utils::Curl::Response::Das;

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
const my $MIN_ERROR => 400;

use base qw(Pagesmith::Utils::Curl::Response);

sub set_r {
  my( $self, $r ) = @_;
  $self->{'r'} = $r;
  return $self;
}

sub r {
  my $self = shift;
  return $self->{'r'};
}

sub set_das_url {
  my( $self, $das_url ) = @_;
  $self->{'das_url'} = $das_url;
  return $self;
}

sub das_url {
  my $self = shift;
  return $self->{'das_url'};
}

sub sources {
  my $self = shift;
  return $self->{'_sources_'};
}

sub add_body {
  my( $self, $chunk ) = @_;
  ## We need to just need to push content to the browser!
  if( $self->{'success'} ) {
    unless( exists $self->{'not_first_chunk'} ) {
      my $cl = length $chunk;
      $chunk =~ s{<[?]xml-stylesheet.*?[?]>}{}mxs;
      $chunk =~ s{<[?]xml-stylesheet.*?[?]>}{}mxs;
      $chunk =~ s{<!DOCTYPE}{<?xml-stylesheet type="text/xsl" href="/core/css/das.xsl" ?>\n<!DOCTYPE}mxs;
      $chunk =~ s{<!DOCTYPE\s+([[:upper:]]+)\s+SYSTEM\s+(['"]).*?(\w+[.]dtd)\2\s*>}{<!DOCTYPE $1 SYSTEM "http://www.biodas.org/dtd/$3">}mxs; ## no critic (ComplexRegexes)
      ## no critic (ComplexRegexes)
      $chunk =~ s{(<[_[:upper:]]+[ ](?:.*?[ ])?href=")([^"?]+?)(/[^/?]+/[^/?]+(?:[?][^"]*|)")}{$1.$self->das_url.$3}mesxi;
      ## use critic
      $self->{'not_first_chunk'} = 1;
      if( exists $self->{'length'} ) {
        $self->r->err_headers_out->add( 'Content-Length',
          $self->{'length'} - $cl + length $chunk );
      }
    }
    $self->r->print( $chunk );
  } else {
    ## Clear the stored body (we will treat this as a normal Curl Response in the case of an error
    ## rather than a streaming response!)
    $chunk =sprintf qq(<?xml version="1.0" encoding="UTF-8"?>\n<error>\n<![CDATA[\n\n%s\n\n]]>\n</error>),
      $chunk;
    $self->{'body'} = [ $chunk ];
    $self->flush_header( 'Content-Length', length $chunk );
  }
  return length $chunk;
}

sub add_head {
  my( $self, $chunk ) = @_;
  chomp $chunk;
  $chunk =~ s{\s+\Z}{}mxs;    ## Remove trailing whitespace.
  $self->{'success'} = 1 unless exists $self->{'success'};
  if( $chunk =~ m{\AHTTP/\d[.]\d\s*(\d+)\s*(.*)}mxs ) {    ## Handle the HTTP line
    my ( $code, $text ) = ($1,$2);
    $self->{'success'} = $code < $MIN_ERROR ? 1 : 0;
    $self->{'code'}    = $code;
    $self->{'text'}    = $text;
    if( $self->{'success'} ) {
      $self->r->err_headers_out->set( 'Status'   => "$code $text" );
      $self->r->status_line( $chunk );
      $self->r->status(      $code );
    }
  } elsif( $self->{'success'} ) {
    if( $chunk =~ m{\A(.*?):\s*(.*)}mxs ) {              ## Handle all other header lines
      my $key = lc $1;
      if( $key eq 'content-length' ) {
        $self->{'length'} = $2;
      } else {
        $self->r->err_headers_out->add($key,$2);
      }
    }
  } else {
    ## Push the header! (we will treat this as a normal Curl Response in the case of an error
    ## rather than a streaming response!)
    $self->SUPER::add_head( $chunk );
  }
  return;
}

1;
