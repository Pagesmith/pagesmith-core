package Pagesmith::Utils::Curl::Response::Das::DSN;

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

use base qw(Pagesmith::Utils::Curl::Response::Das);

sub add_body {
  my( $self, $chunk, $req ) = @_;
  return unless length $chunk;
  $self->{'_sources_'}||={};
  $self->{'_chunk_'} ||= q();
  $self->{'_chunk_'} .= $chunk;
  while( $self->{'_chunk_'} =~ s{(.*?</DSN>)}{}mxs ) {
    my $ch = $1;
    $self->{'_sources_'}{$2}= $1 if $ch =~ m{(<DSN.*?id="(.*?)".*)\Z}mxs;
  }
  return;
}

sub add_head {
  return;
}

1;
