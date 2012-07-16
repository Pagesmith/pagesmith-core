package Pagesmith::Component::EntryPortal;

## Component
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
Readonly my $OFFSET => 55;

use base qw(Pagesmith::Component::File);

use HTML::Entities qw(encode_entities);
use Image::Magick;
use Image::Size qw(imgsize);

sub _cache_key {
  my $self = shift;
  return $self->checksum_parameters();
}

sub execute {
  my $self = shift;
  ## Check file exists....

  my @Q     = $self->pars;
  my $url   = encode_entities( shift @Q );
  my $img   = encode_entities( shift @Q );
  my $title = encode_entities( shift @Q );
  if( $self->option( 'wrap' ) ) {
    $title = sprintf '<%s>%s</%s>', $self->option('wrap'), $title, $self->option('wrap');
  }
  my $body  = join q( ), @Q;
     $body  = encode_entities( $body ) unless $self->option( 'raw' );

  my $about_info = encode_entities( $self->option('about') ) || $title;
  my $class = $self->option('noframe') ? q(clear-float ep-plain) : q(panel);
  my $image_html;
  if ( $self->option('offset') ) {
    my ( $x, $y ) = map { -$OFFSET * $_ } split m{:}mxs, $self->option('offset');
    $image_html = sprintf '<img src="/core/gfx/blank.gif" class="thumb" alt="%s" style="background: #fff url(%s) no-repeat %dpx %dpx" />', $title, $img, $y, $x;
  }  else {
    $image_html = sprintf '<img src="%s" class="thumb" alt="%s" />', $img, $title;
  }
  return sprintf '<div class="%s"><h3>%s</h3><p>%s%s</p></div>', $class, $title, $image_html, $body if $url eq q(#);
  return sprintf
'<div class="%s"><h3><a href="%s">%s</a></h3><p><a href="%s">%s</a>%s</p><p class="more"><a href="%s"><img src="/core/gfx/blank.gif" alt="More information about %s" /></a></p></div>',
      $class, $url, $title, $url, $image_html, $body, $url, $about_info;
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

