package Pagesmith::Component::YouTube;

## Component to display YouTube videos
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

use base qw(Pagesmith::Component);

use HTML::Entities qw(encode_entities);

sub usage {
  my $self = shift;
  return {
    'parameters'  => '[{key=s} {caption=s}]+',
    'description' => 'Display an embedded YouTube video - size/positioning is dependent on the template used',
    'notes'       => [
      '{key} code for video as in http://www.youtube.com/v/...',
      '{caption} caption to appear under the video',
    ],
  };
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'template', 'defn' => q(=s), 'default' => 'small',
      'description' => 'Template to use to render elements', 'values'=>qw(small small-right centered large) },
    { 'code' => 'channel',  'defn' => q(=s), 'default' => q(),
      'description' => 'If set the video(s) is/are wrapped in an HTML panel with a link to the channel as defined', },
  );
}

sub my_cache_key {
  my $self = shift;
  return $self->checksum_parameters();
}

my $templates = {
  'small' => q(<p class="youtube-small"><object width="160" height="115" type="application/x-shockwave-flash" data="http://www.youtube.com/v/%s"><param name="movie" value="http://www.youtube.com/v/%s" />Video resource: %s  </object></p>),
  'small-right' => q(<p class="right youtube-small"><object width="160" height="115" type="application/x-shockwave-flash" data="http://www.youtube.com/v/%s"><param name="movie" value="http://www.youtube.com/v/%s" />Video resource: %s  </object></p>),
  'centered' => q(<div class="c youtube-large"><object width="480" height="295" type="application/x-shockwave-flash" data="http://www.youtube.com/v/%s"><param name="movie" value="http://www.youtube.com/v/%s" />Video resource: %s</object></div>),
  'large' => q(<div class="right youtube-large"><object width="480" height="295" type="application/x-shockwave-flash" data="http://www.youtube.com/v/%s"><param name="movie" value="http://www.youtube.com/v/%s" />Video resource: %s</object></div>),
};

sub execute {
  my $self = shift;
  my $html = ();
  my $template = $self->option('template','small');
  my @Q = $self->pars;
  while ( my ( $key, $caption ) = splice @Q, 0, 2 ) {
    $caption = q() unless defined $caption;
    $html .= sprintf $templates->{$template}, $key, $key, $caption;
  }
  return $html unless $self->option( 'channel' );
  return $self->wrap( {
    'title' => 'Video channel',
    'html'  => $html,
    'link'  => 'http://www.youtube.com/'.$self->option('channel'),
  } );
}

1;

__END__

h3. Sytnax

<% YouTube
  -template=(small|large)
  -channel=s
  ("key" "caption")+
%>

h3. Purpose

Create a "Video channel" "portlet" on the main page, includes zero or more
you tube video thumbnails @size 160x115 and links to the named channel
YouTube channel...  key is the 11 character you tube code, and caption is
the place holder text for text readers (for accessibility requirements)...

h3. Options

* format (opt default small) - Size to render either (small) 160x115 or (large)
  480x295

* channel (opt) - Include a portlet wrapper to include link to a youtube channel

h3. Notes

* Default format is small but not wrapped (to be embedded in the RHS column of the page)

h3. See also

* CSS: core/css/pagesmith-classes.css - contains CSS to format p/div

