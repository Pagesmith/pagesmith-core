package Pagesmith::Component::FeatureImage;

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

use base qw(Pagesmith::Component::Image);

use HTML::Entities qw(encode_entities);    ## HTML entity escaping

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'credit', 'defn' => '=s', 'default' => q(), 'description' => 'Caption for image' },
    { 'code' => 'nocredit', 'description' => 'No caption for image' },
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
  my $credit = sprintf '[%s]', $self->credit( $self->option('credit') );
  $credit = q() if $self->option( 'nocredit' );
  my $extra_class = q();
  my $class_flag = $self->option('class');
  $extra_class .= sprintf ' class="%s"', encode_entities( $class_flag ) if $class_flag;
  if ( $self->option('popup') ) {
    return
      sprintf
'<div id="featureR"><div%s style="background-image:url(%s)"></div><p class="zoom"><a href="%s" class="btt no-img thickbox" title="%s">zoom</a>%s</p></div>',
      $extra_class,
      encode_entities($img),
      encode_entities($img),
      encode_entities( $cap || $img ),
      $credit;
  } else {
    $credit = sprintf '<p>%s</p>', $credit if $credit;
    return sprintf '<div id="featureR"><div%s style="background-image:url(%s)"></div>%s</div>',
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

