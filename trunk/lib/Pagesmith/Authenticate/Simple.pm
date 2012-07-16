package Pagesmith::Authenticate::Simple;

## Authenticate using Ldap
## Author         : mw6
## Maintainer     : mw6
## Created        : 2010-11-05
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use List::MoreUtils qw(all);

use base qw(Pagesmith::Authenticate);

sub new {
  my( $class, $conf ) = @_;
  my $self = {
    'users'         => $conf->{'users'},
    'encrypted'     => $conf->{'encrypted'},
    'groups'        => exists $conf->{'groups'} ? $conf->{'groups'} : {},
  };
  bless $self, $class;
  return $self;
}

sub users {
  my $self = shift;
  return $self->{'users'};
}

sub encrypted {
  my $self = shift;
  return $self->{'encrypted'};
}

sub authenticate {
  my( $self, $username, $pass, $parts ) = @_;
  return {} unless exists $self->users->{$username};
  my( $password, $name ) = @{ $self->users->{$username} };
  if( $self->encrypted ) {
    $pass = crypt $pass, $password;
  }
  return {} unless $password eq $pass;
  return {(
    'id'      => $username,
    'name'    => $name,
    'groups'  => $self->user_groups( $username ),
  )};
}

1;
