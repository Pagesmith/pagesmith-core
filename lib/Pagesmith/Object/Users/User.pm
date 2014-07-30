package Pagesmith::Object::Users::User;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
#| This file is part of the User account management extensions to
#| Pagesmith web framework.
#+----------------------------------------------------------------------
#| The User account management extensions to Pagesmith web framework is
#| free software: you can redistribute it and/or modify it under the
#| terms of the GNU Lesser General Public License as published by the
#| Free Software Foundation; either version 3 of the License, or (at
#| your option) any later version.
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

## Author         : James Smith <js5@sanger.ac.uk>
## Maintainer     : James Smith <js5@sanger.ac.uk>
## Created        : 30th Apr 2014

## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Object::Users);
use Pagesmith::Utils::ObjectCreator qw(bake);
use Const::Fast qw(const);

const my $SALT_LENGTH => 16;
const my $COST        =>  8;

use MIME::Base64 qw(encode_base64 decode_base64);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash);
use Data::UUID;

## Last bit - bake all remaining methods!
bake();

sub check_password {
  my( $self, $pw ) = @_;
  return $self->get_password eq $self->_encrypt_password( $pw, $self->get_password );
}

sub set_password {
  my ( $self, $pw ) = @_;
  ## We run the password through encryption algorithm before we store it in the database!
  return $self->std_set_password( $pw eq q() ? q() : $self->_encrypt_password( $pw ) );
}

sub _encrypt_password {
  my( $self, $pw, $salt ) = @_;
  if( $salt ) {
    $salt = substr decode_base64($salt), 0, $SALT_LENGTH;
  } else {
    $salt = Data::UUID->new->create;
  }
  return encode_base64( $salt.bcrypt_hash({'key_nul'=>1,'cost'=>$COST,'salt'=>$salt},encode_base64($pw)), q() );
}
1;

__END__

Purpose
=======

Object classes are the basis of the Pagesmith OO abstraction layer

Notes
=====

What methods do I have available to me...!
------------------------------------------

This is an auto generated module. You can get a list of the auto
generated methods by calling the "auto generated"
__PACKAGE__->auto_methods or $obj->auto_methods!

Overriding methods
------------------

If you override an auto-generated method a version prefixed with
std_ will be generated which you can use within the package. e.g.

sub get_name {
  my $self = shift;
  my $name = $self->std_get_name;
  $name = 'Sir, '.$name;
  return $name;
}

