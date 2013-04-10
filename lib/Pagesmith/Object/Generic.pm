package Pagesmith::Object::Generic;

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

use base qw(Pagesmith::Object);

sub new {
  my($class,$adaptor,$object_data) = @_;
     $object_data    ||= {};
  my $self    = {
    '_adpt'      => $adaptor,
## Information about the object and it's ID
    'type'       => $object_data->{'type'},
    'id'         => $object_data->{'id'},
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
  my( $self, $value ) = @_;

  my $method = our $AUTOLOAD;

  return $self->set( $1, $value ) if $method =~ m{::set_(\w+)\Z}mxs;
  return $self->get( $1 )         if $method =~ m{::get_(\w+)\Z}mxs;
  return $self->get_date( $1 )    if $method =~ m{::date_(\w+)\Z}mxs;
  return $self->unset( $1 )       if $method =~ m{::unset_(\w+)\Z}mxs;
  return $self->get( $1 )         if $method =~ m{::(\w+)\Z}mxs;
  return $self;
}

sub can {
  my( $self, $method ) = @_;
  return 1 if $method =~ m{\Aset_(\w+)\Z}mxsg;
  return 1 if $method =~ m{\A(?:get_|date_|unset_|)(\w+)\Z}mxsg && exists $self->{'objdata'}{$1};
  return $self->SUPER::can( $method );
}

sub get_date {
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

## no critic (BuiltinHomonyms)
sub state {
  my $self = shift;
  return $self->{'state'};
}
## use critic

sub change_state {
  my( $self, $value ) = @_;
  $self->{'state'} = $value;
  return $self;
}

sub objdata {
  my $self = shift;
  return $self->{'objdata'};
}

1;