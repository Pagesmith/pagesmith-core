package Pagesmith::Component::SecondaryNavigation;

## Component to generate secondaryary blue bar nav
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

use base qw(Pagesmith::Component::Navigation);

use Const::Fast qw(const);
const my $URL_PARTS_SUB => 4;

sub usage {
  my $self = shift;

  return {
    'parameters'  => q(),
    'description' => 'Displays the secondary navigation tabs on the webpage',
    'notes'       => [],
    'see_also'    => { 'sites/{site_name}/data/config/{site_name}.yaml' => 'Contains the YAML file' },
  };
}

sub my_cache_key {
  my $self = shift;
  my @Q = split m{/}mxs, $self->page_path, $URL_PARTS_SUB;
  return @Q[1, 2];
}

sub execute {
  my $self = shift;
  my @n    = $self->nav_conf;
  my ( $zz, $primary, $secondary ) = split m{/}mxs, $self->page_path, $URL_PARTS_SUB;
  $secondary ||= q();
  my $t;
  foreach my $ref (@n) {
    $t = $ref if ($ref->[0] =~ m{\A(.*?)[|]}mxs ? $1 : $ref->[0]) eq $primary;
  }
  $t ||= $n[0];

  my ( $k, $caption, @menu ) = @{$t};
  return '<div id="NavTabs2"></div>' unless @menu;
  my $html = sprintf '<div id="NavTabs2"><ul id="Tabs2">';
  foreach my $ref (@menu) {
    my( $path, $cap, $url ) = @{$ref};
    my $X = q();
    if( $path =~ m{\Ahttps?:}mxs ) {    ## External link...
      $html .= sprintf '<li><a class="no-img" href="%s">%s&nbsp;&nbsp;</a></li>',
        $self->encode( $path ),
        $self->encode( $cap );
    } elsif ( $path =~ m{^/}mxs ) {    ## Absolute link!
      $html .= sprintf '<li%s><a href="%s">%s</a></li>',
        $path eq $self->page->uri ? ' class="active"' : q(),
        $self->encode( $path ),
        $self->encode( $cap );
    } else {                            ## Relative link...
      $url = $self->encode( "/$primary/$path/" ) unless defined $url;
      $html .= sprintf '<li%s><a href="%s">%s</a></li>',
        $secondary eq $path ? ' class="active"' : q(),
        $self->encode( $url ),
        $self->encode( $cap );
    }
  }
  $html .= '</ul></div>';

  return $html;
}

1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

