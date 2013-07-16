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
  my( $self, $chunk, $req ) = @_;
  ## We need to just need to push content to the browser!
  unless( exists $self->{'not_first_chunk'} ) {
    my $cl = length $chunk;
    $chunk =~ s{<[?]xml-stylesheet.*?[?]>}{}mxs;
    $chunk =~ s{<!DOCTYPE}{<?xml-stylesheet type="text/xsl" href="/das/das.xsl" ?>\n<!DOCTYPE}mxs;
    ## no critic (ComplexRegexes)
    $chunk =~ s{(<[[:upper:]]+[ ]href=")([^"?]+?)(/[^/?]+/[^/?]+(?:[?][^"]*|)")}{$1.$self->das_url.$3}mesxi;
    ## use critic
    $self->{'not_first_chunk'} = 1;
    if( exists $self->{'length'} ) {
      $self->r->err_headers_out->add( 'Content-Length',
        $self->{'length'} - $cl + length $chunk );
    }
  }
  $self->r->print( $chunk );
  return length $chunk;
}

sub add_head {
  my( $self, $chunk, $req ) = @_;
  chomp $chunk;
  $chunk =~ s{\s+\Z}{}mxs;    ## Remove trailing whitespace.
  if( $chunk =~ m{\AHTTP/\d[.]\d\s*(\d+)\s*(.*)}mxs ) {    ## Handle the HTTP line
    my ( $code, $text ) = ($1,$2);
    $self->r->err_headers_out->set( 'Status'   => "$code $text" );
    $self->r->status_line( $chunk );
    $self->r->status(      $code );
    $self->{'success'} = $code < $MIN_ERROR ? 1 : 0;
    $self->{'code'}    = $code;
  } elsif ( $chunk =~ m{\A(.*?):\s*(.*)}mxs ) {              ## Handle all other header lines
    my $key = lc $1;
    if( $key eq 'content-length' ) {
      $self->{'length'} = $2;
    } else {
      $self->r->err_headers_out->add($key,$2);
    }
  }
  return;
}

1;

__END__
sub add_head {
121   my ( $self, $chunk ) = @_;
124   if ( $chunk =~ m{\AHTTP/(\d[.]\d)\s*(\d+)\s*(.*)}mxs ) {    ## Handle the HTTP line
125     $self->{'http_version'} = $1;
126     $self->{'code'}         = $2;
127     $self->{'text'}         = $3;
128   } elsif ( $chunk =~ m{\A(.*?):\s*(.*)}mxs ) {              ## Handle all other header lines
129     my $key = lc $1;
130     push @{ $self->{'headers'}{ $key } }, $2;
131   }
132   return;
133 }

