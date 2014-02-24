package Pagesmith::Adaptor::DbInc;

## Adaptor for comments database
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

use base qw(Pagesmith::BaseAdaptor);

use Pagesmith::ConfigHash qw(is_developer);

sub connection_pars {
  return 'objectstore';
}

sub get_message {
  my( $self, $code, $realms ) = @_;
  $realms = q() unless $realms;
  my $res = $self->row_hash( 'select content,status from message where code = ?', $code );
  return unless defined $res;
  return $res->{'status'} eq 'inactive'                          ? q()
       : $res->{'status'} eq 'active' || is_developer( $realms ) ? $res->{'content'}
       :                                                           q()
       ;
  return q();
}

sub set_message {
  my( $self, $username, $code, $body, $status ) = @_;
  return;
}
1;
