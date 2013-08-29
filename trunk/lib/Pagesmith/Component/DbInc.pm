package Pagesmith::Component::DbInc;

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

use base qw(Pagesmith::Component);

sub usage {
  return (
    'parameters'  => 'key',
    'description' => 'Returns a valid XHTML fragment from the database',
    'notes'       => [],
  );
}

sub execute {
  my $self = shift;

  my $msg = $self->get_adaptor( 'DbInc' )->get_message( $self->next_par );
  return '<span class="web-error">Unknown message code</span>' unless defined $msg;
  return $msg;
}

1;

__END__

h3. Syntax

<% Qr %>

h3. Purpose

Insert a QR image and link into the top right of the page

h3. Options

None

h3. Notes

An automatically generated Qr code is given to the page IF the URL is not already in the Qr database - note if you
want a specific QR code for a page you can manually insert this into the QR table

h3. See also

* Pagesmith::Adaptor::Qr

* Pagesmith::Action::Qr

h3. Examples

None

h3. Developer notes

See Adaptor module for information about the qr image generation code and the database schema
