package Pagesmith::Action::Users::EmailSent;

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

## Admin table display for objects of type User in
## namespace Users

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

use base qw(Pagesmith::Action::Users Pagesmith::SecureSupport);

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;

  return $self->redirect_secure unless $self->is_secure;
  $self->decrypt_input( 'users' );
  my $email_address = $self->next_path_info;
  return $self->not_found unless $email_address;

  return $self->wrap( q(Email sent), sprintf
    '<p>An email has been sent to the account "%s" to. Please read this email and follow the instructions with in it.</p>',
    $self->encode( $email_address ),
  )->ok;
  ## use critic
}

1;

__END__
Notes
-----

