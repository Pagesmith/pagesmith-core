package Pagesmith::Action::Svg;

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

## Dumps raw HTML of the file to the browser (syntax highlighted)
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

use base qw(Pagesmith::Action);

# Modules used by the code!
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);

use Image::Magick;

sub run {
  my $self = shift;
  my $format = $self->next_path_info;
  my $key    = $self->next_path_info || q();
  $key =~ s{[^-.\w]}{}mxgs;
  $key = 'out' if $key eq q();
  if( $format eq 'png' ) {
    $self->r->content_type('image/png');
    $self->r->headers_out->set('Content-Disposition' => 'attachment; filename='.$key.'.png' );
    my $image = Image::Magick->new( 'magick' => 'svg' );
    $image->BlobToImage( $self->param('svg') );
    my $tmp_filename = $self->tmp_filename($format);
    my $res = $image->Write($tmp_filename);
    my $return = system 'optipng', '-o2', '-q', '-preserve', $tmp_filename;
    return $self->not_found unless open my $fh, '<', $tmp_filename;
    local $INPUT_RECORD_SEPARATOR = undef;
    my $img = <$fh>;
    close $fh; ##no critic (CheckedSyscalls CheckedClose)
    return $self->print( $img )->ok;
  }
  $self->r->content_type('image/svg+xml');
  (my $svg = $self->param('svg')) =~ s{\s+xlink:title=}{ title=}mxsg;
  return $self->download( "$key.svg", \$svg );
}

1;
