package Pagesmith::Action::Users::Register;

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
use Const::Fast qw(const);
const my $LEN => 8;

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;
  return $self->redirect_secure      unless $self->is_secure;
  return $self->redirect( '/users/Me' )  if $self->user->logged_in;

  my $form = $self->registration_form; ## Create form - and check for parameters etc.....

  my $form_code = $self->next_path_info;
  if( $form_code ) {
    my $login_form = $self->form_by_code( $form_code );
    $form->update_attribute( 'ref', $login_form->attribute( 'ref' ) );
  }

  my $em_addr = $form->element('email_address')->scalar_value;

  if( $self->is_post && ! $form->is_invalid ) {
    ## See if the account already exists - if so return error page....
    my $user = $self->adaptor( 'User' )->fetch_user_by_method_email( 'user_db', $em_addr );
    return $user ? $self->user_already_exists( $user, $em_addr )
                 : $self->create_user_and_send_email( $form, $em_addr );
  }

  return $self->my_wrap(
    q(Register),
    '<% LoremIpsum 2 paras %>'.$form->render,
  );
}

sub registration_form {
## Generate registration form!
  my $self = shift;
  ## no critic (LongChainsOfMethodCalls)
  my $form = $self->stub_form->make_simple->make_form_post->set_url( '/users/Register');
  ## use critic
     $form->add( 'Email',       'email_address' );
     $form->add( 'String',      'name'          );
#     $form->add( 'SetPassword', 'password'      )->set_strength( 'vstrong', $LEN );
     ## no critic (ImplicitNewlines LongChainsOfMethodCalls)
     $form->add( 'CheckBox',    'terms'         )
          ->set_caption( 'Terms and conditions' )
          ->remove_layout( 'eighty20' )
          ->set_notes('
          <div style="border:1px solid #333" class="check-seen scrollable vert-sizing {padding:400,minheight:200}">
            <h3>Terms and conditions</h3>
            <% LoremIpsum 20 paras %>
          </div>')
          ->set_inline( 'I agree to the following terms and conditions' );
     ## use critic
     $form->bake;
  return $form;
}


sub user_already_exists {
## Can't register user which already exists - so show an error!
  my ( $self, $user, $em_addr ) = @_;
  my $enc_em_addr = $self->encrypt_url( 'users', $em_addr );
  ## no critic (ImplicitNewlines)
  if( $user->get_status eq 'pending' ) {
    return $self->my_wrap( 'User already exists', sprintf
      q(<p>It appears that this is the second time you have tried to create this account</p>
        <p>Click here to <a href="/users/InviteReminder/%s">resend the initial invite email</a></p>' ),
      $enc_em_addr,
    );
  }
  return $self->my_wrap( 'User already exists', sprintf
    q(<p>I'm sorry we are unable to set up that account the user already exists.</p>
      <p>Please try a different email address OR <a href="/users/ForgotPassword/%s">reset password</a></p>' ),
    $enc_em_addr,
  );
  ## use critic
}


sub create_user_and_send_email {
## Create new user - using Pagsmith::Adaptor::Users::User then
##  * store in database,
##  * Send email to user
##  * redirect to email sent page!
  my ( $self, $form, $em_addr ) = @_;
  my $enc_em_addr = $self->encrypt_url( 'users', $em_addr );

  ## no critic (LongChainsOfMethodCalls ImplicitNewlines)
  my $user = $self->adaptor( 'User' )->create
    ->set_email(    $em_addr )
    ->set_method(  'user_db' )
    ->set_name(     $form->element( 'name'     )->scalar_value )
#    ->set_password( $form->element( 'password' )->scalar_value )
    ->store;
  my $validate_url = $self->base_url.'/users/V/'.$user->get_code;

  my $email = $self->mail_message
    ->format_mime
    ->set_subject(    'Account regsitration and email validation' )
    ->get_templates(  'template' )
    ->add_email_name( 'To', $em_addr )
    ->add_markdown( '
Account regsitration and email validation
=========================================
Dear user,

We have created your accound and it is in a pending state
until we can validate this email.
' )
    ->add_list( 'To validate your email (and activate your account) follow the link below',
        [ $validate_url ] )
    ->add_markdown( '
Please note this link will be active for the next two days
after this time it will be deactivated, and you will have to
complete this form again.
')
    ->send_email;
  ## use critic
    return $self->redirect( '/users/EmailSent/'.$enc_em_addr );
}

1;

__END__
Notes
-----

