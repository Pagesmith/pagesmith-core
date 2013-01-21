package Pagesmith::Component::Navigation;

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

use Readonly qw(Readonly);
Readonly my $URL_PARTS => 3;

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
