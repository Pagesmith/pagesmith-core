package Pagesmith::AdaptorMethods;

## Base class for auto-creating methods from configuration...!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Thu, 23 Jan 2014
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Socket        qw(inet_ntop AF_INET6 AF_INET);
use Sys::Hostname qw(hostname);
use English       qw(-no_match_vars $PROGRAM_NAME);

use base qw(Pagesmith::Adaptor);

## Functions that munge the object configuration structure
## Merge in relationships!

sub attach_user {
  my( $self, $adapt ) = @_;
  $self->{'_user_details' } = $adapt->{'_user_details'};
  return $self;
}

sub user_id {
#@params (self)
#@return (string)
## Returns key to database connection in configuration file
  my $self = shift;
  return $self->{'_user_details'}{'id'};
}

sub user_username {
#@params (self)
#@return (string)
## Returns key to database connection in configuration file
  my $self = shift;
  return $self->{'_user_details'}{'username'};
}

sub user_ip {
#@params (self)
#@return (string)
## Returns key to database connection in configuration file
  my $self = shift;
  unless( $self->{'_user_details'}{'ip'} ) {
    if( exists $self->{'_r'} ) {
      $self->{'_user_details'}{'ip'} = $self->r->headers_in->{'X-Forwarded-For'} || $self->remote_ip;
    } else {
      my $hn = scalar gethostbyname hostname() || 'localhost';
      $self->{'_user_details'}{'ip'} = inet_ntop( AF_INET, $hn );
    }
  }
  return $self->{'_user_details'}{'ip'};
}

sub user_useragent {
#@params (self)
#@return (string)
## Returns key to database connection in configuration file
  my $self = shift;
  return $self->{'_user_details'}{'useragent'} ||=
    exists $self->{'_r'} ? $self->r->headers_in->{'User-Agent'} || q(--)
                         : "$ENV{q(SHELL)} $PROGRAM_NAME"
                         ;
}

1;
