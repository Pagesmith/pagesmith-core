package Pagesmith::Action::Js5Blast;

## Generate a login form - the rest of the login form is handled by the form action!!!
##
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action);

sub run {
  my $self = shift;
  ## Initialize a form object and render it in the page... we will then use the form action handler to do the rest!
  my $form;

  $form = $self->form_by_code( $self->param( 'ticket_id' ) ) if $self->param( 'ticket_id' ); ## Do we have a valid ticket

  $form ||= $self->form( 'Js5Blast', $self->next_path_info ); ## No we don't so generate a new ticket!

  return $self->redirect( $form->action_url_get );
}
1;
