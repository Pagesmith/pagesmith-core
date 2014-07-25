package Pagesmith::Adaptor;

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

use base qw(Pagesmith::BaseAdaptor);
use Pagesmith::Core qw(user_info);

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

sub attach_user_script {
  my $self = shift;
  my $user_info = user_info();
  my $un = $user_info->{'username'}.q(@).$self->mail_domain;
  if( $un ) {
    $self->{'_user_details'} = {
      'id'       => $self->sv('select user_id from user where email = ?', $un )||0,
      'username' => $un,
    };
  } else {
    $self->{'_user_details'} = { 'id' => 0, 'username' => '-script-' };
  }
  return $self;
}

sub attach_user_web {
## Attach user for security/audit purposes...
  my( $self, $user )  = @_;
  if( $user->username ) {
    $self->{'_user_details'} = {
      'id'       => $self->sv('select user_id from user where email = ?', $user->username )||0,
      'username' => $user->username,
    };
  } else {
    $self->{'_user_details'} = { 'id' => 0, 'username' => '-web-' };
  }
  return $self;
}

sub get_other_adaptor {
## Returns a database adaptor for the given type of object.
  my( $self, $type ) = @_;
  my $adaptor = $self->get_adaptor_from_pool( $type );
  return $adaptor || $self->get_adaptor( $self->base_class.q(::).$type, $self )
                          ->attach_user( $self )
                          ->add_self_to_pool( $type );
}

1;
