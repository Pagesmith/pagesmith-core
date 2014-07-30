package Pagesmith::Action::Users::R;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
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

## Reset user password email verification URL - URL is purposefully short so doesn't get foobarred
## in email!

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

use Const::Fast qw(const);
const my $PASSWORD_LENGTH => 8;

use Pagesmith::Core qw(safe_md5);

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;

  return $self->redirect_secure unless $self->is_secure;

  my $key = $self->next_path_info;

  my $reset_obj = $self->adaptor( 'PwChange' )->fetch_pwchange_by_code( $key );
  return $self->my_wrap(
    'Password Change',
    '<p>Unfortunately we do not recognise the password change token provided</p>',
  ) unless $reset_obj;

  ## no critic (LongChainsOfMethodCalls ImplicitNewlines)
  my $form = $self->stub_form->make_simple->make_form_post;
     $form->add( 'SetPassword', 'new_password' )->set_strength( 'vstrong', $PASSWORD_LENGTH );
     $form->bake;

  if( $self->is_post && ! $form->is_invalid  ) {
    my $pw = $form->element('new_password')->scalar_value;
    my $user = $self->adaptor('User')->fetch_user( $reset_obj->get_user_id );
    return  $self->my_wrap( 'Password change', '<p>The code you have entered is no longer valid</p>' )
      if safe_md5( $user->get_password ) ne $reset_obj->get_checksum;
    if( $user ) {
      $user->set_password( $pw )->store;
      my $email = $self->mail_message
        ->format_mime
        ->set_subject(    'Reset password' )
        ->add_email_name( 'To', $user->get_email )
        ->get_templates(  'template' );
      $email->add_markdown( "Reset password\n==================\n\nDear user\n\nYour password has recently been reset" );
      $email->send_email;
      $_->remove foreach @{$self->adaptor('PwChange' )->fetch_pwchanges_by_user( $user )};
    }
    return $self->my_wrap( q(Reset password),
      '<p>If the email address you entered has an account registered against it
        you will shortly receive an email with further instructions</p>' );
  }
  return $self->my_wrap( q(Reset password),
    '<p>To finish reseting your password enter the new password below</p>'.
    $form->render,
  );
  ## use critic
}

1;

__END__
Notes
-----

