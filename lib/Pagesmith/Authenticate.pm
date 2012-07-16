package Pagesmith::Authenticate;

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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Support);

sub new {
  my( $class, $conf ) = @_;
  return;
}

sub groups {
  my $self = shift;
  return keys %{ $self->{'groups'} };
}

sub group_members {
  my( $self, $gp ) = @_;
  return @{ $self->{'groups'}{$gp} };
}

sub user_groups {
  my( $self, $user_id ) = @_;
  my @groups;
  foreach my $gp ( $self->groups ) {
    my @members = $self->group_members( $gp );
    push @groups, $gp if !@members || any { $_ eq $user_id } @members;
  }
  return \@groups;
}

1;
