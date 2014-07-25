package Pagesmith::Component::FacultyImage;

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
    { 'code' => 'nocredit',       'defn' => q(),   'description' => q(Don't display credit) },
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
  $html .= sprintf '<p class="portrait">[%s]</p>', $self->credit( $self->option('credit') ) unless $self->option('nocredit');
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

