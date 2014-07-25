package Pagesmith::Utils::Bcrypt;

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

## Encrypt a password using bcrypt. See also Authen::Passphrase::BlowfishCrypt
## Only able to create the same hash if you know the password
### Interface:
# user->new({'username'=> 'password'=> })
#  hashtext = $user->encode_password();
#  boolean  = $user->is_valid( ciphertext );
## Author         : mw6
## Maintainer     : mw6
## Created        : 2012-04-25
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use Carp qw(carp);
use utf8;
use English '-no_match_vars';

use version qw(qv); our $VERSION = qv('0.1.0');

use Const::Fast qw(const);
const my $SECONDS_PER_DAY   => 86_400_000; # 60*60*24      * 1000
const my $LOCAL_EPOCH_START => 15.455;   # 2012 April 25 / 1000
const my $MAX_USERNAME      => 60; # later we will take shasum of username, not store username

const my $KEY_NUL           => 1; # Truth value: whether to append a NUL to the password before using it as a key. The algorithm as originally devised does not do this, but it was later modified to do it. The version that does append NUL is to be preferred; not doing so is supported only for backward compatibility.
const my $COST              => 13; # Non-negative integer controlling the cost of the hash function. The number of operations is proportional to 2^cost.
const my $SALT_LENGTH       => 16; # 16 random octets
const my $MAX_BCRYPT_PASSWORD => 72; # bcrypt will probably ignore anything longer than 72 'octets'.
const my $MESSAGE_COLUMN => 3; # the third column contains salt + hash

use MIME::Base64 qw(encode_base64 decode_base64);
use Digest::SHA qw(sha512_base64);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash);
use Crypt::OpenSSL::Random qw(random_bytes);

sub new {
  my ($package,$args) = @_;
  my $self = bless {}, $package;
  if ($args) {
    # NB: Returns nothing if username or password not provided
    $self->{'username'} = $args->{'username'} || return;
    $self->{'password'} = $args->{'password'} || return;
  }
  $self->{'username'} = substr $self->{'username'}.('U'x$MAX_USERNAME),0,$MAX_USERNAME;
  $self->{'rollover'} = $self->rollover();
  return $self;
}

sub rollover {
#                 int(
#                     (
#                      (
#                       time / 86400   : seconds -> days
#                      ) - 15455       : 25th April 2012.
#                     ) / 1000         : in 1000 days, all passwords are invalid [unless we review things and change the number above]
#                    );
  my $rollover = int( time / $SECONDS_PER_DAY - $LOCAL_EPOCH_START ); # 2 sets of brackets removed
  return substr '9h5dp25',$rollover,1;
}

sub get_string {
  my ($self) = @_;
  my $username = $self->{'username'};
  $username =~ tr{\@\.}{}d; # avoid guaranteed letters like @ and . (com might be one as well)
  return (substr q().sha512_base64( $self->{'password'} . $self->{'salt'} . $self->{'rollover'} . lc reverse $username ),0,$MAX_BCRYPT_PASSWORD);
}

sub encode_password {
  my $self = shift;
  $self->{'salt'} ||= random_bytes($SALT_LENGTH); # only replace salt if not set by is_valid
  my $hashtext = bcrypt_hash({
     'key_nul' => $KEY_NUL,
     'cost'    => $COST,
     'salt'    => $self->{'salt'},
     }, $self->get_string( ) );
##no critic (InterpolationOfMetachars)
  return q($2y$).$COST.q($).encode_base64($self->{'salt'}.$hashtext, q() );
##use critic (InterpolationOfMetachars)
}

sub is_valid {
  my ($self, $hashtext) = @_;
  if ($hashtext) { # take the part at the end.
    $self->{'salt'} = (substr decode_base64((split /\$/sxm,$hashtext)[$MESSAGE_COLUMN]),0,$SALT_LENGTH) || q();
    return ($self->{'salt'} && $hashtext eq $self->encode_password);
  }
}

1;
