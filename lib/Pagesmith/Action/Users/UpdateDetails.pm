package Pagesmith::Action::Users::UpdateDetails;

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
use Const::Fast qw(const);
const my $LEN => 8;

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;

  return $self->redirect_secure unless $self->is_secure;
  return $self->login_required unless $self->user->logged_in;

  ## Now check to see if method is "user_db":
  return $self->my_wrap( q(Can not edit account), '<p>You are using an external authentication method and so you can not change your account details here</p>' )
    unless $self->user->auth_method eq 'user_db';

  my $form_code = $self->next_path_info;
  ## Create form....
  my $form = $self->stub_form->make_simple->make_form_post;
     $form->add( 'Email',          'email_address' )->set_default_value( $self->user->email );
     $form->add( 'String',         'name'          )->set_default_value( $self->user->name );
     $form->add( 'SetPassword',    'new_password'  )->set_default_value(q())->set_do_not_store->set_optional->set_strength( 'vstrong', $LEN ); ## no critic (LongChainsOfMethodCalls)
     $form->add( 'Password',       'current_password'  )->set_default_value(q())->set_do_not_store;

  if( $form_code ) {
    $form->update_from_cache( $form_code );
    $self->dumper( [$form->attribute('user_chck'),$self->user_cs] );
    return $self->no_permission if $form->attribute( 'user_code') ne $self->user->uid;
    return $self->my_wrap( q(Form is no longer valid), '<p>Changes have already been made.</p>' )
      if $form->attribute('user_chck') ne $self->user_cs;
  } else {
    $form->add_attribute( 'user_code', $self->user->uid );
    $form->add_attribute( 'user_chck', $self->user_cs );
    $form->store;
  }
  $form->set_url('/users/UpdateDetails/'.$form->code);
  $form->bake;
  if( $self->is_post && $form_code ) {
    my $new_email = $form->element( 'email_address' )->scalar_value;
    my $new_name  = $form->element( 'name'          )->scalar_value;
    my $new_pass  = $form->element( 'new_password'  )->scalar_value;
    my $old_pass  = $form->element( 'current_password'  )->scalar_value;
    my $user = $self->adaptor( 'User' )->fetch_user_by_method_code( 'user_db', $form->attribute( 'user_code' ) );
    return $self->no_permission unless $user; ## SOMETHING IS WELL FOOBARED HERE!
    ### Incorrect pas:q
    if( $user->check_password( $old_pass ) ) {
      if( $new_email ne $self->user->email ) { ## We need to an email...
        my @time = $self->adaptor('EmailChange')->offset( 1, 'day' );
      ## Create password change object!
        ## no critic (LongChainsOfMethodCalls)
        my $evo = $self->adaptor('EmailChange')->create
          ->set_user(       $user )
          ->set_oldemail(   $user->get_email )
          ->set_newemail(   $new_email )
          ->set_expires_at( $time[0] )
          ->store;
        $self->mail_message
          ->format_mime
          ->set_subject(    'Validate email' )
          ->add_email_name( 'To', $new_email )
          ->get_templates(  'template' )
          ->add_markdown( 'You have requested that your email be updated
====================================

To complete this process please follow the following email
validation link
' )
          ->add_list( 'To validate your new email visit:', [ $self->base_url.'/users/E/'.$evo->get_code ] )
          ->send_email;
        ## use critic
        $self->flash_message( {
          'title' => 'Updating account details',
          'body'  => '<p>You have requested to update your email address. An email has been sent to you with instructions on how to complete this process, any other details you have made have been updated</p>',
        });
      } else {
        $self->flash_message( {
          'title' => 'Updating account details',
          'body'  => '<p>You details have been updated</p>',
        });
      }

      $user->set_password( $new_pass ) if $new_pass;
      $user->set_name(     $new_name );
      $self->user->set_attribute( 'name', $new_name )->store;
      $user->store;
      $form->completed;
      $self->redirect('/users/Me');
    } else {
      $self->redirect('/users/UpdateDetails/'.$form->code);
    }
  }
  return $self->wrap( q(Update details),
    '<p>To update your details in our database modify the details in the form, enter your password and click "submit"</p>'.
    $form->render,
  )->ok;
}

sub user_cs {
  my $self = shift;
  my $s = join q(:), $self->user->email, $self->user->name;
  my $r = safe_md5( $self->escape($s) );
  return $r;
}
1;

__END__
Notes
-----

