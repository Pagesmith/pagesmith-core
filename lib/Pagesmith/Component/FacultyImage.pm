package Pagesmith::Component::FacultyImage;

## Component to render a faculty image
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

use base qw(Pagesmith::Component::FeatureImage);

use HTML::Entities qw(encode_entities);    ## HTML entity escaping

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'credit', 'defn' => '=s', 'default' => q(), 'description' => 'Credit for image' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{image} {caption}*',
    'description' => 'Display image with caption for faculty pages',
    'notes'       => [],
  };
}

sub execute {
  my $self = shift;
  my ( $img, @name ) = $self->pars;
  my $name = "@name";

  my $html = sprintf '<div class="facultyImage" style="background-image:url(%s)">', encode_entities($img);
  $html .= sprintf '<p>%s</p>', encode_entities($name) if $name;
  $html .= '</div>';
  $html .= sprintf '<p class="portrait">[%s]</p>', $self->credit( $self->option('credit') );
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

