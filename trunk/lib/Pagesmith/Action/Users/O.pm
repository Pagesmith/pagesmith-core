package Pagesmith::Action::Users::O;

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

## Cancel an account!
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

sub run {
#@params (self)
## Display admin for table for User in Users
  my $self = shift;

  return $self->redirect_secure unless $self->is_secure;

  my $code = $self->next_path_info;

  my $user = $self->adaptor( 'User' )->fetch_user_by_method_code( 'user_db', $code );

  return $self->redirect( '/users/Me' ) if $user && $user->get_status ne 'active';

  if( $user && $user->get_status eq 'cancelled' ) {
    if( $self->is_post ) {
      $user->set_status( 'active' )->store;
      ## no critic (LongChainsOfMethodCalls)
      my $email = $self->mail_message
        ->format_mime
        ->set_subject(    'Re-open account' )
        ->add_email_name( 'To', $user->get_email )
        ->get_templates(  'template' )
        ->add_markdown( 'Your account has been re-opened
====================================

Your account has been re-opened and any associated details
have been restored where possible.

' )
        ->add_list( 'To see details of your account visit:', [ $self->base_url.'/users/Me' ] )
        ->send_email;
      ## use critic
      $self->flash_message({
        'title' => 'Your account has been re-opened',
        'body'  => '<p>You will now need to <a href="/login">login to your account</a> to see the details</p>',
      });
      $self->redirect( '/users/Me' );
    } else {
      my $form = $self->stub_form->make_simple->make_form_post;
         $form->add( 'Information', '<p>Click below to re-open your account</p>' );
         $form->add( 'String', 'email' )->set_default_value( $user->get_email )->set_readonly;
         $form->add( 'String', 'name'  )->set_default_value( $user->get_name )->set_readonly;
         $form->add( 'CheckBox', 'accept' )->set_caption( 'I would like to reopen my account.' );
         $form->add( 'Information', '<p>To delete your account - check the checkbox above and click on cancel button below.</p>' );
         $form->bake;
      return $self->my_wrap( q(Re-open account), $form->render );
    }
  }
  return $self->my_wrap( 'Do not recognise account details', '<p>The link you supplied is either corrupted or out of date</p>' );
  ## use critic
}

1;

__END__
Notes
-----

