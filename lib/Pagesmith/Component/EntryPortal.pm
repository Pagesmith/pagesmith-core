package Pagesmith::Component::EntryPortal;

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

use Const::Fast qw(const);
const my $OFFSET => 55;

use base qw(Pagesmith::Component::File);

use HTML::Entities qw(encode_entities);
use Image::Magick;
use Image::Size qw(imgsize);

sub my_cache_key {
  my $self = shift;
  return $self->checksum_parameters();
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'wrap',     'defn' => '=s', 'description' => 'Wrap title within a tag' },
    { 'code' => 'raw',      'description' => 'Embed raw HTML for body' },
    { 'code' => 'noframe',  'description' => 'Do not include panel div' },
    { 'code' => 'offset',   'defn' => '=s', 'description' => 'Offset in sprited image' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{url} {img} {title} {body}*',
    'description' => 'Display image with caption for faculty pages',
    'notes'       => [],
  };
}

sub execute {
  my $self = shift;
  ## Check file exists....

  my @Q     = $self->pars;
  my $url   = encode_entities( shift @Q );
  my $img   = encode_entities( shift @Q );
  my $title = shift @Q;
     $title = encode_entities( $title ) unless $self->option( 'raw' );
  if( $self->option( 'wrap' ) ) {
    $title = sprintf '<%s>%s</%s>', $self->option('wrap'), $title, $self->option('wrap');
  }
  my $body  = "@Q";
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
'<div class="%s"><h3><a href="%s">%s</a></h3><p><a href="%s" class="no-img">%s</a>%s</p><p class="more"><a class="btt no-img" href="%s" title="more information about %s">more</a></p></div>',
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

