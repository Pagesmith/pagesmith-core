package Pagesmith::Action::FormFile;

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
