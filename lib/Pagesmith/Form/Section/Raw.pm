package Pagesmith::Form::Section::Raw;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2014 Genome Research Ltd.
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

##
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

use base qw( Pagesmith::Form::Section);

use Carp qw(carp);
use Digest::MD5 qw(md5_hex);
use List::MoreUtils qw(any);
use HTML::Entities qw(encode_entities);

my $_offset = 0;

sub is_invalid {
  my $self = shift;
  return 0;
}
sub new {
  my ( $class, $page, $section_data ) = @_;
  my $self = {
    'config'          => $page->form_config,
    'id'              => $section_data->{'id'} || $page->form_config->next_id,
    'classes'         => { map { $_=>1 } $page->form_config->classes('section') },
    'caption'         => $section_data->{'caption'},
    'body'            => $section_data->{'body'},
  };

  bless $self, $class;
  return $self;
}

sub form_config {
  my $self = shift;
  return $self->{'config'};
}

sub update_from_apr {
  return;
}

#= Class manipulation functions...
# Allows classes to be added to all sections (e.g. adding panel class to give
# them rounded borders etc) or all elements

sub classes {
#@param (self)
#@return (string+) list of classes
## Return the list of classes associated with the form!
  my $self =shift;
  my @classes = sort keys %{ $self->{'classes'} };
  return @classes;
}

sub add_class {
#@param (self)
#@param (string) $class CSS class to add to form
  my ( $self, $class ) = @_;
  $self->{'classes'}{$class} = 1;
  return $self;
}

## Accessors
sub set_id {
  my( $self, $value ) = @_;
  $self->{'id'} = $value;
  return $self;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub set_caption {
  my( $self, $value ) = @_;
  $self->{'caption'} = $value;
  return $self;
}

sub caption {
  my $self = shift;
  return $self->{'caption'};
}

sub body {
  my $self = shift;
  return $self->{'body'};
}
sub render {
#@param (self)
#@return (HTML) Form rendered in HTML.
## Render the section of the form.
  my $self = shift;

  my $html = "\n    <div";
  my $x = join q( ), $self->classes;
  $html .= sprintf ' class="%s"', $x if $x;
  $html .= q(>);
  $html .= $self->{'button_html'}{'top'}    if exists $self->{'button_html'}{'top'};

  if( $self->caption ) {
    $html .= sprintf "\n      <h3>%s</h3>", encode_entities( $self->caption );
  }
  $html .= $self->body;
  $html .= $self->{'button_html'}{'bottom'}    if exists $self->{'button_html'}{'bottom'};
  $html .= "\n    </div>";
  return $html;
}

sub render_readonly {

#@param (self)
#@return (HTML) Form rendered in HTML.
## Render the section of the form.
  my $self = shift;
  return $self->render;
}

sub render_paper {
#@param (self)
#@return (HTML) Form rendered in HTML.
## Render the section of the form.
  my $self = shift;
  return $self->render;
}

1;
