package Pagesmith::BaseObject;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
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
