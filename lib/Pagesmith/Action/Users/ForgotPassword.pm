package Pagesmith::Action::Users::ForgotPassword;

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

use Pagesmith::Core qw(safe_md5);

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;

  return $self->redirect_secure unless $self->is_secure;

  my $email_address = q();
  if( $self->path_info ) {
    my $error     = $self->decrypt_input( 'users' );
    $email_address = $self->next_path_info;
  }

  ## Create form....
  my $form = $self->stub_form->make_simple->make_form_post;
     $form->add( 'Email',       'email_address' )->set_default_value( $email_address||q() );
     $form->bake;

  my $form_code = $self->next_path_info;
  if( $form_code ) {
    my $login_form = $self->form_by_code( $form_code );
    $form->update_attribute( 'ref', $form->attribute( 'ref' ) );
  }

  ## Now see if post!
  if( $self->is_post ) {
    $email_address = $form->element('email_address')->scalar_value;

    my $user = $self->adaptor('User')->fetch_user_by_method_email( 'user_db', $email_address );
    if( $user && $user->get_status eq 'active' ) {
      ## no critic (LongChainsOfMethodCalls)
      my $email = $self->mail_message
        ->format_mime
        ->set_subject( 'Forgotten password' )
        ->add_email_name( 'To', $email_address )
        ->get_templates( 'template' );
      my @time = $self->adaptor('PwChange')->offset( 1, 'day' );

      ## Create password change object!
      my $pw_reset = $self->adaptor('PwChange')->create
        ->set_user(       $user )
        ->set_checksum( safe_md5( $self->encode( $user->get_password ) ) )
        ->set_expires_at( $time[0] )
        ->store;
      ## use critic
      my $reset_url = $self->base_url.'/users/R/'.$pw_reset->get_code;
      $email->add_markdown( "Forgotten password\n==================\n\nDear user\n\n" );
      $email->add_list( 'To reset your password visit the following link',
        [ $reset_url ] );
      $email->send_email;
    }
    return $self->wrap( q(Forgotten password),
      '<p>If the email address you entered has an account registered against it
        you will shortly receive an email with further instructions</p>' )->ok;
  }
  return $self->wrap( q(Forgotten password),
    '<p>To reset your password please enter your email address in the box below</p>'.
    $form->render,
  )->ok;
  ## use critic
}

1;

__END__
Notes
-----

