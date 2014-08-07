package Pagesmith::Action::Users::C;

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

## Cancel an account! File name is short as this is included in email
## so to prevent chopping only use a single character!

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

  if( $user && $user->get_status eq 'active' ) {
    if( $self->is_post ) {
      $user->set_status( 'cancelled' )->store;
      ## no critic (LongChainsOfMethodCalls)
      my $email = $self->mail_message
        ->format_mime
        ->set_subject(    'Cancel account' )
        ->add_email_name( 'To', $user->get_email )
        ->get_templates(  'template' )
        ->add_markdown( 'Your account has been cancelled
====================================

Your account has been cancelled - it will be deleted after  3 months.
In this period you will be able to re-activate your account without
associated details being deleted.
' )
        ->add_list( 'To reopen your account please follow this link:', [ $self->base_url.'/users/O/'.$user->get_code ] )
        ->send_email;
      ## use critic
      return  $self->my_wrap( 'Your account has been cancelled',
          '<p>You will recieve an email shortly - if you wish to re-instate your account follow the instructions in the email</p>' );
    } else {
      my $form = $self->stub_form->make_simple->make_form_post;
         $form->add( 'String', 'email' )->set_default_value( $user->get_email )->set_readonly;
         $form->add( 'String', 'name'  )->set_default_value( $user->get_name )->set_readonly;
         $form->add( 'CheckBox', 'accept' )->set_caption( 'I would like my account deleted.' );
         $form->add( 'Information', '<p>To delete your account - check the checkbox above and click on cancel button below.</p>' );
         $form->current_stage->set_next('Confirm cancellation');
         $form->bake;
      return $self->my_wrap( q(Cancel account), $form->render );
    }
    return $self->my_wrap( 'Do not recognise account details', '<p>The link you supplied is either corrupted or out of date</p>' );
  }
  ## use critic
}

1;

__END__
Notes
-----

