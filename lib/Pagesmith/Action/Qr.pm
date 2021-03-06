package Pagesmith::Action::Qr;

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

## Handles external links (e.g. publmed links)
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
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use Const::Fast qw(const);
const my $ONE_WEEK => 86_400 * 7;

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Adaptor::Qr;

sub run {
  my $self  = shift;
  return $self->no_content unless get_config( 'QrEnabled' );
  my $qr_url = get_config( 'QrURL' ) || $self->base_url.'/qr/';

  my $key   = $self->next_path_info;
  my $image = $key =~ s{[.]png\Z}{}mxs ? 1 : 0;

  unless( $image ) {
    my $qr_obj = Pagesmith::Adaptor::Qr->new()->get_by_code( $key );
    return $qr_obj && $qr_obj->url ? $self->redirect( $qr_obj->url ) : $self->no_content;
  }

  my $ch = Pagesmith::Cache->new( 'tmpfile', "qr|$key.png" );    ## Generate the image....
  my $img_content = $ch->get;

  unless( $img_content ) {
    my $tmp_filename = $self->tmp_filename('.png');
    my $return = system 'qrencode', '-m', '1', '-s', '2', '-l', 'Q', '-8', '-v', '3', '-o', $tmp_filename, $qr_url.$key;
    return $self->no_content if $return;
    $return = system 'optipng', '-o2', '-q', '-preserve', $tmp_filename;
    return $self->no_content unless open my $fh, '<', $tmp_filename;
    local $INPUT_RECORD_SEPARATOR = undef;
    $img_content = <$fh>;
    close $fh; ## no critic (RequireChecked)
    unlink $tmp_filename;
    $ch->set( $img_content );
  }

  return $self
    ->content_type( 'image/png' )
    ->set_last_modified( time - $ONE_WEEK )
    ->set_expires_header( 1, 'YEAR' )
    ->set_length( length $img_content )
    ->print( $img_content )
    ->ok;
}

1;
