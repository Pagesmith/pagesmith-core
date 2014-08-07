package Pagesmith::Action::Users::E;

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

## Reset user email email verification URL - URL is purposefully short
## so doesn't get foobarred in email!

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

  ## Get password request object that has been sent!
  my $reset_obj = $self->adaptor( 'EmailChange' )->fetch_emailchange_by_code( $self->next_path_info );

  return $self->my_wrap(
    'Email Change',
    '<p>Unfortunately we do not recognise the email change token provided</p>',
  ) unless $reset_obj;

  return $self->login_required  unless $self->user->logged_in;
  return $self->no_permission   unless $self->user->auth_method eq 'user_db';

  my $user = $self->adaptor('User')->fetch_user_by_method_code( 'user_db', $self->user->uid );

  return $self->my_wrap(
    'Email Change',
    '<p>Unfortunately the email change token provided is not for this account</p>',
  ) unless $user->get_user_id == $reset_obj->get_user_id
        && $user->get_email   eq $reset_obj->get_oldemail;

  ## no critic (LongChainsOfMethodCalls ImplicitNewlines)
  my $form = $self->stub_form->make_simple->make_form_post;
     $form->add( 'Email', 'oldemail' )->set_caption( 'Old email address' )->set_default_value( $reset_obj->get_oldemail )->set_readonly;
     $form->add( 'Email', 'newemail' )->set_caption( 'New email address' )->set_default_value( $reset_obj->get_newemail )->set_readonly;
     $form->add( 'Information', '<p>Click below to change your email address.</p>' );
     $form->bake;

  if( $self->is_post && ! $form->is_invalid ) {
    ## This will redirect to the user account page!
    $user->set_email( $reset_obj->get_newemail )->store;
    $self->user->set_attribute( 'email', $reset_obj->get_newemail )->store;
    $self->mail_message
      ->format_mime
      ->set_subject(    'Email changed' )
      ->add_email_name( 'To', $reset_obj->get_oldemail )
      ->get_templates(  'template' )
      ->add_markdown( sprintf 'Email changed
==================

Dear user

Your email has recently been change to:

 * %s

from

 * %s

',
          $reset_obj->get_newemail, $reset_obj->get_oldemail )
      ->send_email;
    $self->flash_message({
      'title' => 'Your email address has been changed',
      'body'  => sprintf '<p>Your email address has been changed to %s from %s</p>',
        $self->encode( $reset_obj->get_newemail ),
        $self->encode( $reset_obj->get_oldemail ),
    });
    $_->remove foreach @{$self->adaptor('EmailChange' )->fetch_emailchanges_by_user( $user )};
    return $self->redirect( '/users/Me' );
  }
  ## use critic
  return $self->my_wrap( q(Email change),
    '<p>To finish changing your email check the details are correct.</p>'.
    $form->render,
  );
}

1;

__END__
Notes
-----

