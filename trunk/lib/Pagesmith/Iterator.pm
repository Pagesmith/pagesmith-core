package Pagesmith::Iterator;

## Base class for other web-adaptors...
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

## Supplies wrapper functions for DBI

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

sub new {
  my ( $class, $sth ) = @_;
  my $self = { 'sth' => $sth };
  bless $self, $class;
  return $self;
}

sub get {
  my $self = shift;
  my $row = $self->{'sth'}->fetchrow_hashref;
  return $row if $row;
  $self->{'sth'}->finish;
  return;
}

sub finish {
  my $self = shift;
  return unless $self->{'sth'};
  $self->{'sth'}->finish;
  return;
}

1;
