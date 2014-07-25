package Pagesmith::Component::Qr;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(),
    'description' => q(Display a block containing a QR code link and the QR code image),
    'notes'       => [],
  };
}

sub execute {
  my $self = shift;
  return q() unless get_config( 'QrEnabled' );
  my $r = $self->r;
  return q() if $r->args;
  return q() if $r->headers_out->get('X-Pagesmith-NoQr');
  my $qr_url = get_config( 'QrURL' );
  my $qr_code;
  my $host = $r->headers_in->{'Host'};
  foreach my $val ( $r->headers_out->get('X-Pagesmith-QrCode') ) {
    if( $val =~ m{\A(.*)=(.*)\Z}mxs ) {
      $qr_code = $2 if $1 eq $host;
    }
  }
  my $adap = Pagesmith::Adaptor::Qr->new();
  my $key  = $self->base_url( $r ). $r->uri;
  $key =~ s{/index[.]html}{/}mxs; ## remove trailing index.html
  my $qr_obj = $adap->get_by_url( $key );
  if( defined $qr_code && ( !defined $qr_obj || $qr_obj->code ne $qr_code ) ) {
    my $qr_obj_fixed = $adap->create({'url' => $key, 'prime'=>'yes','code'=>$qr_code});
    if( $qr_obj_fixed->store ) {
      $qr_obj = $qr_obj_fixed;
    }
  }
  unless( $qr_obj ) {
    $qr_obj = $adap->create({'url' => $key, 'prime'=>'yes',});
    return q() unless $qr_obj->store;
  }
  return sprintf '<div class="qr"><a href="%s%s"><img height="62" width="62" alt="* quick link - %s%s" src="/qr/%s.png" /></a></div>', $qr_url, $qr_obj->code, $qr_url, $qr_obj->code, $qr_obj->code;
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
