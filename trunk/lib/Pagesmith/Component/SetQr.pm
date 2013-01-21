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
