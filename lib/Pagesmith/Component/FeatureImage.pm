package Pagesmith::Component::FeatureImage;

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

use base qw(Pagesmith::Component::Image);

use HTML::Entities qw(encode_entities);    ## HTML entity escaping

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'credit', 'defn' => '=s', 'default' => q(), 'description' => 'Caption for image' },
    { 'code' => 'class',  'defn' => '=s', 'default' => q(), 'description' => 'Additional classes for feature div' },
    { 'code' => 'popup',                  'description' => 'Wheter image is clickable to bring up a thick box panel' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{image} {caption}*',
    'description' => 'Display image in resizing box on feature pages',
    'notes'       => [],
  };
}

sub execute {
  my $self = shift;
  my ( $img, @cap ) = $self->pars;
  my $cap = "@cap";
  my $credit = $self->credit( $self->option('credit') );

  my $extra_class = q();
  my $class_flag = $self->option('class');
  $extra_class .= sprintf ' class="%s"', encode_entities( $class_flag ) if $class_flag;
  if ( $self->option('popup') ) {
    return
      sprintf
'<div id="featureR"><div%s style="background-image:url(%s)"></div><p><a href="%s" class="thickbox" title="%s"><img alt="Enlarge this image" src="/core/gfx/blank.gif" /></a>[%s]</p></div>',
      $extra_class,
      encode_entities($img),
      encode_entities($img),
      encode_entities( $cap || $img ),
      $credit;
  } else {
    return sprintf '<div id="featureR"><div%s style="background-image:url(%s)"></div><p>[%s]</p></div>',
      $extra_class,
      encode_entities($img),
      $credit;
  }
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

