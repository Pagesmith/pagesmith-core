package Pagesmith::Utils::Curl::Response::Das::Sources;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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
  $self->{'_chunk_'} =~ s{<!--.*?-->}{}mxsg; ## Remove <!-- --> comments
  my $comment = q();
  if( $self->{'_chunk_'} =~ s{(<!--).*}{}mxs ) { ## We have a partial comment so remove it!
    $comment = $1;
  }

  while( $self->{'_chunk_'} =~ s{(.*?</SOURCE>)}{}mxs ) {
    my $block = $1;
    $block =~ s{.*?(<SOURCE\s)}{$1}mxs;
    my @capability = $block =~ m{<CAPABILITY\s+(.*?)>}mxsg;
    foreach my $line (@capability) {
      my ($type) = $line =~ m{type="das1:(.*?)"}mxs;
      my ($url)  = $line =~ m{query_uri="(.*?)"}mxs;
      my @parts = split m{/}mxs, $url;
      pop @parts if $type eq $parts[-1];
      my $k = pop @parts;
      $self->{'_sources_'}{$k} = $block;
      last;
    }
  }
  $self->{'_chunk_'}.=$comment; ## Put back the partial comment!
  return;
}

sub add_head {
  return;
}

1;
