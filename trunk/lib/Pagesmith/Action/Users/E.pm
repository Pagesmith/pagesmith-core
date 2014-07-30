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

use Pagesmith::Core qw(safe_md5);

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;

  return $self->redirect_secure unless $self->is_secure;

  my $key = $self->next_path_info;

  my $reset_obj = $self->adaptor( 'EmailChange' )->fetch_emailchange_by_code( $key );
  return $self->my_wrap(
    'Email Change',
    '<p>Unfortunately we do not recognise the password change token provided</p>',
  ) unless $reset_obj;

  my $user = $self->adaptor('User')->fetch_user_by_method_code( 'user_db', $self->user->uid );

  return $self->my_wrap(
    'Email Change',
    '<p>Unfortunately we do not recognise the password change token provided</p>',
  ) unless $reset_obj;

  return $self->my_wrap(
    'Email Change',
    '<p>Unfortunately cannot update your account unless</p>',
  ) unless $user->get_user_id == $reset_obj->get_user_id
        && $user->get_email   eq $reset_obj->get_oldemail;

  ## no critic (LongChainsOfMethodCalls ImplicitNewlines)
  my $form = $self->stub_form->make_simple->make_form_post;
     $form->add( 'Email', 'oldemail' )->set_caption( 'Old email address' )->set_default_value( $reset_obj->get_oldemail )->set_readonly;
     $form->add( 'Email', 'newemail' )->set_caption( 'New email address' )->set_default_value( $reset_obj->get_newemail )->set_readonly;
     $form->add( 'Information', '<p>Click below to change your email address.</p>' );
     $form->bake;

  if( $self->is_post && ! $form->is_invalid ) {
    $user->set_email( $reset_obj->get_newemail )->store;
    $self->user->set_attribute( 'email', $reset_obj->get_newemail )->store;
    $self->mail_message
      ->format_mime
      ->set_subject(    'Email changed' )
      ->add_email_name( 'To', $reset_obj->get_oldemail )
      ->get_templates(  'template' )
      ->add_markdown( "Email changed\n==================\n\nDear user\n\nYour email has recently been change to:\n\n * ".
          $reset_obj->get_newemail."\n\nfrom:\n\n * ".$reset_obj->get_oldemail )
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
  return $self->my_wrap( q(Email change),
    '<p>To finish changing your email check the details are correct.</p>'.
    $form->render,
  );
  ## use critic
}

1;

__END__
Notes
-----

