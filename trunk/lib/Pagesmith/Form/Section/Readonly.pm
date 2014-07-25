package Pagesmith::Form::Section::Readonly;

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

sub render {
#@param (self)
#@param (Pagesmith::Form) $form - the parent form object
#@return (HTML) Form rendered in HTML as readonly.
## Render the sections of the form in a readonly way - designed for confirmation and final pages!.

  my( $self, $form ) = @_;

#@note Only do non-Readonly sections, so we don't recurse up our own .....
  my $output = q();
  my $stage_count = 0;
  foreach my $st ( $form->stages ) {
    last if $stage_count == $form->stage;
    $stage_count++;
    $output .= $st->render_readonly( $form, 'readonly_section' );
  }
  $output .= $self->base_render( q(), q() ) if $self->{'button_html'}{'bottom'};
  return $output;
}

sub render_readonly {
#@param (self)
#@return (HTML) Form rendered in HTML.
## Return

  my $self = shift;
  return q();
}

sub render_paper {
#@param (self)
#@return (HTML) Form rendered in HTML.
## Render the section of the form.
  my $self = shift;
  return q();
}

1;
