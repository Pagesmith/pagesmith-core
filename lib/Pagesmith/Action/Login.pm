package Pagesmith::Action::Login;

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
  return $self->redirect( $self->form( 'Login' )->action_url_get );
}
1;
