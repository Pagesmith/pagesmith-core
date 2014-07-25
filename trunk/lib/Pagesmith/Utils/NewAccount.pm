package Pagesmith::Utils::NewAccount;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
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

## Ask an authentication server whether new_account/password is ok
## Author         : mw6
## Maintainer     : mw6
## Created        : 2012-01-05
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

# WA->create_path()
#  returns true on success
# WA->lwp_get(): Make an http request of the authenticating server
##no critic (ProhibitCommentedOutCode)
#   (success:bool,content:$response,error:string) = WA->lwp_get()
##use critic (ProhibitCommentedOutCode)
#   there are all sorts of possible problems with communication that can happen here)
# NB: we ENCRYPT [Crypt::CBC] the username and password and the pass it over http.
#     we create a CHECKSUM specific to the secret (below) + username + password
#     The API_KEY is the only thing not SAFE_ encoded.
# WA->decode_response($response) makes sense of the response
#  $response usually decodes to a hash.

use strict;
use warnings;
use utf8;
use Carp qw(carp croak);

use version qw(qv); our $VERSION = qv('0.1.0');

use Crypt::CBC; # qw decrypt encrypt
use LWP::UserAgent;
use HTTP::Request;

use Const::Fast qw(const);

const my $DEFAULT_TIMEOUT => 3;

use Pagesmith::Core qw(safe_base64_decode safe_base64_encode safe_md5 );
use Pagesmith::ConfigHash qw(get_config);
use base qw(Pagesmith::Support);

sub new {
  my ($class,$args) = @_;

  return unless $args && $args->{'user'};

  my $self  = {
    'user'     => $args->{'user'},
    'password' => $args->{'password'},
    'api_key'  => $args->{'api_key'} || get_config( 'AuthKey' )     || 'auth_key',
    'key'      => $args->{'token'}   || get_config( 'AuthToken' )   || 'auth_token',
    'secret'   => $args->{'secret'}  || get_config( 'AuthSecret' )  || 'auth_secret',
    'server'   => $args->{'server'}  || get_config( 'AuthServer' )  || 'http://localhost',
    'timeout'  => $args->{'timeout'} || get_config( 'AuthTimeout' ) || $DEFAULT_TIMEOUT,
  };

  bless $self, $class;

  return $self;
}

sub cipher {
  my $self = shift;
  return $self->{'cipher'} ||= Crypt::CBC->new(
    '-key'     => $self->{'key'},
    '-cipher'  => 'Blowfish',
    '-header'  => 'randomiv', ## Make this compactible with PHP Crypt::CBC
  );
}

sub create_path {
  my $self     = shift;
  return unless defined $self->{'user'} && $self->{'password'};

  my $encrypted_user     = safe_base64_encode( $self->cipher->encrypt( $self->{'user'} ) );
  my $encrypted_password = safe_base64_encode( $self->cipher->encrypt( $self->{'password'} ) );
  my $encrypted_realname = safe_base64_encode( $self->cipher->encrypt( $self->{'realname'} ) );

  my $checksum = safe_md5( join q(:), $self->{'secret'}, $encrypted_user, $encrypted_password, $encrypted_realname );

  return join q(/),
    $self->{'api_key'},
    $encrypted_user,
    $encrypted_password,
    $encrypted_realname,
    $checksum;
}

sub lwp_get {
  my( $self, $path ) = @_;

  # Create a request
  my $res;
  my $rv = eval {
    my $req = HTTP::Request->new('POST' => "$self->{'server'}/action/User_Create/$path" );
       $req->content_type('application/x-www-form-urlencoded');
       $req->content(q());
    my $ua = LWP::UserAgent->new;
       $ua->agent('Pagesmith_Util_NewAccount/'.$VERSION);
       $ua->timeout( $self->{'timeout'} );
    $res = $ua->request( $req );
  };

  return $res;
}

sub check_new_user {
  my $self = shift;

  my $path = $self->create_path;
  return 'bad username' unless $path;

  my $res  = $self->lwp_get( $path );

  return "System failure [$path]" unless $res && $res->is_success;

  return 'Request Rejected' unless $res->content;

  my $json_obj;
  my $rv = eval { $json_obj = $self->json_decode( $self->cipher->decrypt( safe_base64_decode( $res->content ) ) ); };

  return 'Request failed 2' unless $json_obj;

  $self->{'details'} = $json_obj;
  return $self->{'details'};
}

sub detail {
  my($self, $key ) = @_;
  return $self->{'details'}{$key};
}

sub details {
  my $self = shift;
  return $self->{'details'};
}

1;

# documentation:

__END__

Usage: To ask for new account with this service you will need an $API_KEY and related $key and $secret

wget .../User/Create/$API_KEY/$encrypted_user/$encrypted_pass/$checksum

$encrypted_user = "safe"_base64_encode( encrypt( $user ) );
$encrypted_pass = "safe"_base64_encode( encrypt( $pass ) );
$checksum       = "safe"_md5_base64( $secret':'.$encrypted_user.':'.$encrypted_password )

Encryption is with Crypt::CBC ( -key => $key, -cipher => 'Blowfish';

If you get a valid response ($response) you then need to

  json_decode( decrypt( "safe"_base64_decode( $response ) ) );
