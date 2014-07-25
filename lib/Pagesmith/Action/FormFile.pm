package Pagesmith::Action::FormFile;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2014 Genome Research Ltd.
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
use Pagesmith::Cache;
use MIME::Base64 qw(decode_base64);
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Cache;

sub run {
  my $self  = shift;
  my ( $code, $part, $ndx, $tn ) = $self->path_info;
  my $key = "$code|$part|$ndx";

  return $self->run_tn( $code, $part, $key ) if defined $tn && $tn eq 'tn';

  my $e = Pagesmith::Cache->new( 'form_file', $key );
  my $val = $e->get;
  return $self->not_found unless $e->get;

  my $form = $self->form_by_code( $code );
  return $self->not_found unless $form;
  return $self->not_found unless $form->element( $part );

  my $entry = $form->element( $part )->value->{'files'}{$key};
  return $self->not_found unless $entry;
  $self->download_as( $entry->{'name'} ) if $tn eq 'dl';
  return $self
    ->content_type( $entry->{'type'} )
    ->set_expires_header
    ->set_length( $entry->{'size'} )
    ->print( $val )
    ->ok;
}

sub run_tn {
  my ($self,  $code, $part, $key ) = @_;
  my $form = $self->form_by_code( $code );
  return $self->not_found unless $form;
  return $self->not_found unless $form->element( $part );
  my $entry = $form->element( $part )->value->{'files'}{$key};
  my $contents = decode_base64( $entry->{'tn_blob'} );
  return $self->not_found unless $entry;

  return $self
    ->content_type( $entry->{'tn_mime'} )
    ->set_expires_header
    ->set_length( length $contents )
    ->print( $contents )
    ->ok;
  ## use critic
}

1;
