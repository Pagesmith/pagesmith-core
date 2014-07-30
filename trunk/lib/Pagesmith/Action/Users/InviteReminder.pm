package Pagesmith::Action::Users::InviteReminder;

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
const my $ONE_DAY => 86_400;

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;

  return $self->redirect_secure unless $self->is_secure;

  my $email_address = q();
  if( $self->path_info ) {
    if( $self->path_info_part(0) =~ m{\A-(.{22})\Z}mxs ) {
      my $form = $self->form_by_code( $1 );
      if( $form && $form->element( 'email') ) {
        $email_address = $form->element('email')->scalar_value;
      }
    } else {
      my $error      = $self->decrypt_input( 'users' );
      $email_address = $self->next_path_info;
    }
  }

  my $form = $self->stub_form->make_simple->make_form_post;
     $form->add( 'Email',       'email_address' )->set_default_value( $email_address||q() );
     $form->bake;
  if( $self->is_post && ! $form->is_invalid ) {
    $email_address = $form->element('email_address')->scalar_value;

    my $user = $self->adaptor('User')->fetch_user_by_email( $email_address );
    if( $user && $user->get_status eq 'pending' ) {
      if( $user->get_status eq 'pending' ) {
        my $validate_url =  $self->base_url.'/users/V/'.$user->get_code;
        ## no critic (LongChainsOfMethodCalls)
        my $email = $self->mail_message
          ->format_mime
          ->set_subject( 'Email verfication' )
          ->add_email_name( 'To', $email_address )
          ->get_templates( 'template' );
        ## use critic
        $email->add_markdown( "Email validation\n==================\n\nDear user\n\n" );
        $email->add_list( 'To validate your email (and activate your account) follow the link below',
          [ $validate_url ] );
        $email->send_email;
      }
    }
    return $self->wrap( q(Email validation),
      '<p>If the email address you entered has an account registered against it
        you will shortly receive an email with further instructions</p>' )->ok;
  }
  return $self->wrap( q(Awaiting verification),
    '<p>To verify that you are owner of the email address - check the details are correct and submit this form.</p>'.
    $form->render,
  )->ok;
}

1;

__END__
Notes
-----

