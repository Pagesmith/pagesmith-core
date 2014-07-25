package Pagesmith::Action::Link;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2014 Genome Research Ltd.
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
