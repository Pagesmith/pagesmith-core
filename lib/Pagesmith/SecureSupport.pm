package Pagesmith::SecureSupport;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

## Base class to add common functionality!
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

use Const::Fast qw(const);
use Crypt::CBC;

use Pagesmith::Core qw(safe_base64_decode safe_base64_encode safe_md5);

sub encrypt_url {
  my ( $self, $api_key, @parts ) = @_;
  my $key_config;
  if( @parts && ref $parts[0] eq 'HASH' ) {
    $key_config = shift @parts;
  } else {
    my $pch = $self->config( 'secure' );
         $pch->load(1);
    $key_config = $pch->get( 'keys', $api_key );
    return unless $key_config;
  }

  my $cipher = Crypt::CBC->new( '-key' => $key_config->{'key'}, '-cipher' => 'Blowfish', '-header' => 'randomiv' );
  my @res;
  my $rv = eval {
    push @res, map { safe_base64_encode( $cipher->encrypt( $_ ) ) } @parts;
  };
  my $cs = safe_md5( join q(:), $key_config->{'secret'}, @parts );
  $cs =~ s{=+\Z}{}mxs;
  return join q(/), $api_key, @res, safe_md5( join q(:), $key_config->{'secret'}, @parts );
}

sub decrypt_input {
  my ( $self, $app ) = @_;

  my $pch = $self->config( 'secure' );
     $pch->load(1);
  my $api_key = $self->next_path_info;
  return 'Do not recognise key for app' unless defined $api_key;
  my $key_config = $pch->get( 'keys', $api_key );
  return 'Do not recognise key for app' unless $key_config;
  my $app_config = $pch->get( 'apps', $app );
  return 'Do not recognise key for app' unless $app_config;

  my %keys   = map { $_=>1 } @{$app_config->{'keys'}||[]};
  return 'Do not recognise key for app' unless exists $keys{$api_key};

  my %realms = map { $_=>1 } @{$app_config->{'realms'}||[]};
  if( keys %realms ) {
    my $match = 0;
    my @client_realms = split m{,\s+}mxs, $self->r->headers_in->get('ClientRealm')||q();
    foreach (@client_realms) {
      $match++ if exists $realms{$_};
    }
    return 'Restricted access application' unless $match;
  }

  $self->{'cipher_key'}    = $key_config->{'key'};
  $self->{'cipher_secret'} = $key_config->{'secret'};
  my @parts = $self->path_info;
  my $cs    = pop @parts;
  my @res;
  return 'No path elements' unless @parts;

  foreach my $part ( @parts ) {
    my $v = $self->safe_decrypt( $part );
    return 'Broken encryption' unless defined $v;
    push @res, $v;
  }
  $cs =~ s{=+\Z}{}mxs;
  return 'Mis match checksum' unless $cs eq safe_md5( join q(:), $self->{'cipher_secret'}, @res );

  $self->reset_path_info( @res );

  my @q = $self->param;
  foreach my $q (@q) {
    my $t = $self->param($q);
    if( ref $t ) {
      $self->param( $q, [ map { $self->safe_decrypt( $_ ) } @{$t} ] );
    } else {
      $self->param( $q, $self->safe_decrypt( $t ) );
    }
  }
  return;
}

sub encrypt_data {
  my ( $self, $data_in ) = @_;
  return $self->safe_encrypt( $self->json_encode( $data_in ) );
}

sub cipher {
  my $self = shift;
  return $self->{'cipher'} ||= Crypt::CBC->new(
    '-key'    => $self->{'cipher_key'},
    '-cipher' => 'Blowfish',
    '-header' => 'randomiv', ## Make this compatible with PHP Crypt::CBC
  );
}

sub safe_decrypt {
  my ( $self, $value ) = @_;
  my $rv = eval { $self->cipher->decrypt( safe_base64_decode( $value ) ) };
  return $rv;
}

sub safe_encrypt {
  my ( $self, $value ) = @_;
  my $rv = eval { safe_base64_encode( $self->cipher->encrypt( $value ) ) };
  return $rv;
}

sub send_error {
  my ( $self, $error ) = @_;
  return $self->text->print( $error )->ok;
}

sub send_data {
  my ( $self, $data_in ) = @_;
  return $self->text->print( $self->encrypt_data( $data_in ) )->ok;
}

sub send_response {
  my ( $self, $string ) = @_;
  return $self->text->print( $self->safe_encrypt( $string ) )->ok;
}

1;
