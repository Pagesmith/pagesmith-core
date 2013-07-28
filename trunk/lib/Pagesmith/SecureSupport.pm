package Pagesmith::SecureSupport;

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


sub decrypt_input {
  my ( $self, $app ) = @_;

  my $pch = $self->config( 'secure' );
     $pch->load(1);
  my $api_key = $self->next_path_info;
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
  my ( $self, $data_in ) = shift;
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
