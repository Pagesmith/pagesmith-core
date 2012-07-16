package Pagesmith::Action::Link;

## Handles external links (e.g. publmed links)
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

use base qw(Pagesmith::Action);

sub _get_patterns {
  return { qw(
      pmed http://www.ncbi.nlm.nih.gov.pubmed/$1
  ) };
}

sub run {
  my $self   = shift;
  my $source = $self->next_path_info;
  my @keys   = $self->path_info;

  my $patterns    = $self->_get_patterns();
  my $url_pattern = $patterns->{$source};

  if ($url_pattern) {
    ( my $url = $url_pattern ) =~ s{\$(\d+)}{$keys[$1-1]}mxegs;
    return $self->redirect($url);
  }
  return $self->error( 'Unknown Link Type', qq(<p>I'm sorry but I do not know how to generate a link of type "$source"</p>) );
}

1;
