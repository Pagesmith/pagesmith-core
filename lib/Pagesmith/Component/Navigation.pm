package Pagesmith::Component::Navigation;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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

## Component class for generating navigation bar
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
const my $URL_PARTS => 3;

use base qw(Pagesmith::Component);
use Pagesmith::Config;
use Pagesmith::ConfigHash qw(get_config);

sub usage {
  my $self = shift;

  return {
    'parameters'  => q(),
    'description' => 'Displays the primary navigation tabs on the webpage',
    'notes'       => [],
    'see_also'    => { 'sites/{site_name}/data/config/{site_name}.yaml' => 'Contains the YAML file' },
  };
}

sub page_path {
  my $self = shift;
  $self->{'page_path'} = $self->r->headers_out->get( 'X-Pagesmith-NavPath' ) || $self->page->uri
    unless exists $self->{'page_path'};
  return $self->{'page_path'};
}

sub nav_conf {
  my $self = shift;
  my $filename = get_config( 'Domain' ) || $self->r->server->server_hostname;
  my $pch = Pagesmith::Config->new( { 'file' => $filename, 'location' => 'site' } );
     $pch->load( );
  my $navigation = $pch->get( );
  return @{$navigation||[]};
}

sub my_cache_key {
  my $self = shift;
  my ( $zz, $primary ) = split m{/}mxs, $self->page_path, $URL_PARTS;
  return $primary;
}

sub execute {
  my $self = shift;
  my ( $t, $primary ) = split m{/}mxs, $self->page_path, $URL_PARTS;

  my $html = sprintf '<ul id="navLeft">';
  my @navigation = $self->nav_conf();
  foreach my $ref (@navigation) {
    my ( $key_url, $caption ) = @{$ref};
    my ( $key,$url) = split m{[|]}mxs, $key_url;
    unless( $url ) {
      $url = "/$key";
      $url .= q(/) unless $key =~ m{[.]html\Z}mxs;
      $url =~ s{/index[.]html\Z}{/}mxs;
    }

    $html .= sprintf '<li%s><a href="%s">%s</a></li>',
      $key eq $primary ? ' class="active"' : q(),
      $url,
      $self->encode($caption);
  }
  $html .= '</ul>';

  return $html;
}

1;
