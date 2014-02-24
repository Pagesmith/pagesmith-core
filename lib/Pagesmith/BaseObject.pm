package Pagesmith::BaseObject;

## Base class for other web-objects...
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

## Really naughty as it exposes SQL functionality of adaptor
## But this makes it easier for development!

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Root);

sub init {    # Stub class that does nothing!
}

sub new {
  my ( $class, $adpt, @pars ) = @_;
  my $self = { '_adpt' => $adpt, 'ip' => undef, 'useragent' => undef, 'partial' => 0 };
  bless $self, $class;
  $self->init(@pars);
  return $self;
}

sub adaptor {
  my $self = shift;
  return $self->{'_adpt'};
}
sub sv {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->sv(@pars);
}

sub col {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->col(@pars);
}

sub hash {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->hash(@pars);
}

sub row {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->row(@pars);
}

sub row_hash {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->row_hash(@pars);
}

sub all {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->all(@pars);
}

sub all_hash {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->all_hash(@pars);
}

sub query {
  my ( $self, @pars ) = @_;
  return $self->{'_adpt'}->query(@pars);
}

sub now {
  my $self = shift;
  return $self->{'_adpt'}->now;
}

sub last_id {
  my $self = shift;
  return $self->{'_adpt'}->dbh->{'mysql_insertid'};
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub set_id {
  my( $self, $id ) = @_;
  return $self->{'id'} = $id;
}

sub store {
  my $self = shift;
  return $self->{'_adpt'}->store($self);
}

1;
