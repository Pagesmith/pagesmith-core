package Pagesmith::Component::SetQr;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
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

use Pagesmith::ConfigHash qw(get_config);

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{code=s} {{code=s}={domain=s}}*',
    'description' => 'Add QR-code over-ride header',
    'notes'       => ['Should be in head block'],
  };
}

sub define_options {
  my $self = shift;
  return ();
}

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
