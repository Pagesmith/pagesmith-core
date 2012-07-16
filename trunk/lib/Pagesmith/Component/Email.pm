package Pagesmith::Component::Email;

## Component to insert "escaped email addresses"
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

use base qw(Pagesmith::Component);

sub execute {
  my $self = shift;
  my ( $email, @name ) = $self->pars;
  my $name = join q( ),@name;

  return $self->_safe_email( $email, $name );
}

1;

__END__

h3. Sytnax

<% Email
  email
  (name*)
%>

h3. Purpose

Generate a safe mailto link which escapes all characters in the name and link

h3. Notes

* If name is not supplied email is used instead
