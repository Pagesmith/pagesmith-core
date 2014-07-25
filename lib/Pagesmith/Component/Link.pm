package Pagesmith::Component::Link;

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

## Component to insert "escaped email addresses"
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
const my $TIMEOUT => 2;

use Pagesmith::ConfigHash qw(proxy_url);

use base qw(Pagesmith::Component);

use LWP::Simple qw($ua get);

sub define_options {
  my $self = shift;
  return (
    $self->ajax_option,
    { 'code' => 'length',    'defn' => '=i', 'description' => 'Restrict the length of the URL if the link is longer than this length' },
    { 'code' => 'get_title', 'description' => 'If set retrieve page and parse title from response' },
  );
}

sub usage {
  my $self = shift;
  return {
    'paramters'   => q({name=s}+),
    'description' => 'Push javascript files into the page (either as embed files or src links)',
    'notes'       => [q({name} name of file)],
  };
}

sub ajax {
  my $self = shift;
  return $self->default_ajax;
}

sub execute {
  my $self = shift;
  my ($url) = $self->pars;
  my $extra = {};
  if( $self->option( 'get_title' ) ) {
    $ua->proxy( [qw(http https)], proxy_url );
    $ua->timeout( $TIMEOUT );
    my $response = get $url;
    $extra->{'template'} = '%%title%% (%%url%%)';
    if( ! $response ) {
      $extra->{'title'} = 'Page returns no content';
    } elsif( $response =~ m{<title>(.*?)</title>}mxs ) {
      $extra->{'title'} = $1;
    } else {
      $extra->{'title'} = 'Untitled';
    }
  }
  return $self->safe_link( $url, $self->option( 'length' ), $extra );
}

1;

__END__

h3. Sytnax

<% Link
  -length=N
  url
%>

h3. Purpose

To insert a link into a webpage, but trim the middle out of the link as
displayed in the page if the URL is too long e.g:

  http://www.test.com/thi...est.html

h3. Options

* length (opt) - Length of text links
