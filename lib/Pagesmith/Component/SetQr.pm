package Pagesmith::Component::SetQr;

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
use Pagesmith::Adaptor::Qr;

use Pagesmith::ConfigHash qw(get_config);

sub execute {
  my $self = shift;
  my $r = $self->r;
  my $host     = $r->headers_in->{'Host'};
  my $def_host = get_config( 'Domain' ) || $r->server->server_hostname;

  my @pars = $self->pars;
  foreach my $code ( @pars ) {
    my $domain = $def_host;
    if( $code =~ s{=(.*)}{}mxs ) {
      $domain = $1;
    }
    if( $domain eq $host ) {
      $r->headers_out->set('X-Pagesmith-QrCode',"$domain=$code");
      return q();
    }
  }
  return q();
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
