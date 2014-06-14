package Pagesmith::Object::Qr;

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
    'code'       => $object_data->{'code'},
    'url'        => $object_data->{'url'},
    'prime'      => $object_data->{'prime'},
    'created_at' => $object_data->{'created_at'},
    'created_by' => $object_data->{'created_by'},
  };
  bless $self, $class;
  return $self;
}

sub updated_by {
  my $self = shift;
  return $self->{'updated_by'};
}

sub updated_at {
  my $self = shift;
  return $self->{'updated_at'};
}

sub created_by {
  my $self = shift;
  return $self->{'created_by'};
}

sub created_at {
  my $self = shift;
  return $self->{'created_at'};
}

sub set_code {
  my( $self, $value ) = @_;
  $self->{'code'} = $value;
  return $self;
}

sub code {
  my $self = shift;
  return $self->{'code'};
}

sub set_url {
  my( $self, $value ) = @_;
  $self->{'url'} = $value;
  return $self;
}

sub url {
  my $self = shift;
  return $self->{'url'};
}

sub set_prime {
  my( $self, $value ) = @_;
  $self->{'prime'} = $value;
  return $self;
}

sub prime {
  my $self = shift;
  return $self->{'prime'};
}

1;
