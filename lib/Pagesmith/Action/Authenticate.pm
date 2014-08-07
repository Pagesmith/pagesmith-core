package Pagesmith::Action::Authenticate;

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

## Dumps the headers...
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

use Pagesmith::Core qw(safe_base64_decode safe_base64_encode safe_md5);
use base qw(Pagesmith::Action);

use Pagesmith::Config qw(get);

use Crypt::CBC;

sub run {
  my $self = shift;

  my( $api_key, $user, $pass, $cs ) = $self->path_info;

  my $pch = Pagesmith::Config->new( { 'file' => 'authentication', 'location' => 'site' } );
     $pch->load(1);
  my $conf = $pch->get( 'applications', $api_key );
  return $self->no_content unless $conf;

  my $checksum      = $self->_compute_checksum( "$user:$pass", $conf );

  return $self->no_content unless $checksum eq $cs;

  my $cipher = Crypt::CBC->new(
    '-key'    => $conf->{'key'},
    '-cipher' => 'Blowfish',
    '-header' => 'randomiv', ## Make this compatible with PHP Crypt::CBC
  );

  my $real_password = $cipher->decrypt( safe_base64_decode( $pass ) );
  my $real_username = $cipher->decrypt( safe_base64_decode( $user ) );

  my $methods = $pch->get( 'methods' );
  foreach my $method ( @{$conf->{'methods'}} ) {
    my $authenticator;
    next unless exists $methods->{$method};
    my $m_conf = $methods->{$method};
    my $module = 'Pagesmith::Authenticate::'.$m_conf->{'module'};
    next unless $self->dynamic_use( $module );
    if( exists $m_conf->{'patterns'} ) {
      foreach my $pattern ( @{$m_conf->{'patterns'}} ) {
        if( my @T = $real_username =~ m{\A$pattern\Z}mxs ) {
          $authenticator ||= $module->new( $m_conf );
          my $details = $authenticator->authenticate( $real_username, $real_password, \@T );
          return $self->send_response( $cipher, $method, $details, $m_conf ) if $details->{'id'};
          return $self->no_content if exists $m_conf->{'last'} && $m_conf->{'last'};
        }
      }
    } else {
      $authenticator ||= $module->new( $m_conf );
      my $details = $authenticator->authenticate( $real_username, $real_password, $m_conf, [] );
      return $self->send_response( $cipher, $method, $details, $m_conf ) if $details->{'id'};
    }
  }

  return $self->no_content;
}

sub send_response {
  my( $self, $cipher, $method, $details, $m_conf ) = @_;
  $details->{'method'}  = $method;
  $details->{'subtype'} = $m_conf->{'subtype'} if exists $m_conf->{'subtype'};
  my $response = safe_base64_encode( $cipher->encrypt( $self->json_encode( $details ) ) );
  return $self->text->set_length( length $response )->print( $response )->ok;
}

sub _compute_checksum {
  my( $self, $string, $conf ) = @_;
  return safe_md5( sprintf '%s:%s', $conf->{'secret'}, $string );
}

1;

__END__

h3. Documentation

To authenticate against this service you will need, and $api_key and related $key and $secret

wget .../authenticate/$api_key/$encrypted_user/$encrypted_pass/$checksum

$encrypted_user = "safe"_base64_encode( encrypt( $user ) );

$encrypted_pass = "safe"_base64_encode( encrypt( $pass ) );

$checksum       = "safe"_md5_base64( $secret':'.$encrypted_user.':'.$encrypted_password )

Encryption is with Crypt::CBC ( -key => $key, -cipher => 'Blowfish', -header => 'randomiv' );
 (We use this as it is compatible with equivalent PHP modules!)

If you get a valid response ($response) you then need to

  json_decode( decrypt( "safe"_base64_decode( $response ) ) );
