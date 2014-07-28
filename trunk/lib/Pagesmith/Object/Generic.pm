package Pagesmith::Object::Generic;

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

use base qw(Pagesmith::BaseObject);

sub new {
  my($class,$adaptor,$object_data) = @_;
     $object_data    ||= {};
  my $self    = {
    '_adpt'      => $adaptor,
## Information about the object and it's ID
    'id'         => $object_data->{'id'},
    'type'       => $object_data->{'type'},
    'state'      => $object_data->{'state'} || 'pending',
    'objdata'    => $object_data->{'objdata'} || {},
## Information about the creator/updator of the object
    'created_at' => $object_data->{'created_at'},
    'created_by' => $object_data->{'created_by'},
    'updated_at' => $object_data->{'updated_at'},
    'updated_by' => $object_data->{'updated_by'},
    'ip'         => $object_data->{'ip'},
    'useragent'  => $object_data->{'useragent'},

  };
  bless $self, $class;
  return $self;
}

sub get {
  my( $self, $key ) = @_;
  return unless exists $self->{'objdata'}{$key};
  return $self->{'objdata'}{$key};
}

sub unset {
  my( $self, $key ) = @_;
  delete $self->{'objdata'}{$key} if exists $self->{'objdata'}{$key};
  return $self;
}

## no critic (AmbiguousNames)
sub set {
  my( $self, $key, $value ) = @_;
  $self->{'objdata'}{$key} = $value;
  return $self;
}
## use critic

## no critic (Autoloading,CaptureWithoutTest)
our $AUTOLOAD;

sub AUTOLOAD {
  my ($self,@pars) = @_;

  my $method = our $AUTOLOAD;
  my ($action,$param) = $method =~ m{::(?:(set|get|date|unset)_)?(\w+)\Z}mxs;
  no strict 'refs'; ## no critic (NoStrict)
  unless( defined $param ) {
    *{$method} = sub { warn "Method $method not defined\n"; return; };
  } else {
    $action ||= 'get';
    $action = '_get_date' if $action eq 'date';
    *{$method} = sub { my $self = shift; $self->$action( $param, @_ ); };
  }
  use strict;
  return $self->$method(@pars);
}

sub can {
  my( $self, $method ) = @_;
  return 1 if $method =~ m{\Aset_(\w+)\Z}mxsg;
  return 1 if $method =~ m{\A(?:get_|date_|unset_|)(\w+)\Z}mxsg && exists $self->{'objdata'}{$1};
  return $self->SUPER::can( $method );
}

## no critic (UnusedPrivateSubroutines)
sub _get_date {
  my( $self, $key ) = @_;
  return sprintf '%04d-%02d-%02d %02d:%02d:%02d', map { $self->{'objdata'}{$key}{$_}||0 } qw(year month day hour minute second);
}
## use critic

sub type {

  my $self = shift;
  return $self->{'type'};
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub status {
  my $self = shift;
  return $self->{'state'};
}

sub change_status {
  my( $self, $value ) = @_;
  $self->{'state'} = $value;
  return $self;
}

sub objdata {
  my $self = shift;
  return $self->{'objdata'};
}

sub DESTROY {
}

sub created_at {
  my $self = shift;
  return $self->{'created_at'};
}

sub set_created_at {
  my( $self, $value ) = @_;
  $self->{'created_at'} = $value;
  return $self;
}

sub created_by {
  my $self = shift;
  return $self->{'created_by'}||q(--);
}

sub created_by_id {
  my $self = shift;
  return $self->{'created_by_id'};
}

sub set_created_by {
  my( $self, $value ) = @_;
  $self->{'created_by'} = $value;
  return $self;
}

sub set_created_by_id {
  my( $self, $value ) = @_;
  $self->{'created_by_id'} = $value;
  return $self;
}

sub updated_at {
  my $self = shift;
  return $self->{'updated_at'};
}

sub updated_by {
  my $self = shift;
  return $self->{'updated_by'}||q(--);
}

sub updated_by_id {
  my $self = shift;
  return $self->{'updated_by_id'};
}

sub set_updated_at {
  my( $self, $value ) = @_;
  $self->{'updated_at'} = $value;
  return $self;
}

sub set_updated_by {
  my( $self, $value ) = @_;
  $self->{'updated_by'} = $value;
  return $self;
}

sub set_updated_by_id {
  my( $self, $value ) = @_;
  $self->{'updated_by_id'} = $value;
  return $self;
}

sub ip {
  my $self = shift;
  return $self->{'ip'};
}

sub set_ip {
  my( $self, $value ) = @_;
  $self->{'ip'} = $value;
  return $self;
}

sub useragent {
  my $self = shift;
  return $self->{'useragent'};
}

sub set_useragent {
  my( $self, $value ) = @_;
  $self->{'useragent'} = $value;
  return $self;
}

sub set_ip_and_useragent {
  my $self = shift;
  $self->adaptor->set_ip_and_useragent( $self );
  return $self;
}

1;
