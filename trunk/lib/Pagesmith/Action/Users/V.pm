package Pagesmith::Action::Users::V;

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

## Validate users email address - URL is purposefully short so doesn't get foobarred
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

use base qw(Pagesmith::Action::Users);
use Const::Fast qw(const);
const my $LEN => 8;

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;
  return $self->redirect_secure unless $self->is_secure;
  my $user = $self->adaptor( 'User' )
                  ->fetch_user_by_method_code( 'user_db', $self->next_path_info );

  if( $user ) {
    return $self->redirect( '/users/Me' ) if $self->user->logged_in;
    return $self->my_wrap(
      'Already validated',
      '<p>Your account has already been validated</p>',
    ) if $user->get_status eq 'active';
    if( $user->get_status eq 'pending' ) {
      ## no critic (LongChainsOfMethodCalls)
      my $form = $self->stub_form->make_simple->make_form_post->set_url( '/users/V/'.$user->get_code );
      ## use critic
         $form->set_introduction( '
<p>
  We have now verfified your email (as below). To complete the registration process
  please enter a password in the block below.
</p>' );
         $form->add( 'Email',       'email_address' )->set_readonly->set_obj_data( $user->get_email );
         $form->add( 'String',      'name'          )->set_readonly->set_obj_data( $user->get_name  );
         $form->add( 'SetPassword', 'password'      )->set_strength( 'vstrong', $LEN );
         $form->bake;

      if( $self->is_post && ! $form->is_invalid ) { ## This is the form coming back!
        $user->set_status( 'active' )->set_password( $self->param('password') )->store;
        my $me_url     = $self->base_url.'/users/Me';
        my $cancel_url = $self->base_url.'/users/C/'.$user->get_code;
        ## no critic (LongChainsOfMethodCalls)
        $self->mail_message
          ->format_mime
          ->set_subject(    'Website account set up' )
          ->add_email_name( 'To', $user->get_email )
          ->get_templates(  'template' )
          ->add_markdown( '
Website account setup
=====================

Dear user

')
          ->add_list(
            'The email for your account has been verified - to see details of your account go to', [ $me_url ] )
          ->add_list( 'If you wish to cancel your account please visit:', [ $cancel_url ] )
          ->send_email;
        ## use critic
        return $self->my_wrap(
          'Validated',
          '<p>Your account has been validated, and password set - please remember this the next time you log in.</p>',
        );
      } else {
        return $self->my_wrap( q(Registration continued), $form->render );
      }
    }
  }

  return $self->my_wrap( 'Unrecognised code', '<p>Unrecognised code</p>' );
}

1;

__END__
Notes
-----

