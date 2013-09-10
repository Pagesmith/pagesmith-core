package Pagesmith::Object::GenericFile;

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

use base qw(Pagesmith::Object::Generic);

sub new {
  my($class,$adaptor,$object_data) = @_;
     $object_data    ||= {};
  my $self = $class->SUPER::new( $adaptor, $object_data );
  $self->{'mime_type'} = $object_data->{'mime_type'}||$adaptor->mime_type; ## Copy mime_type from object data!
  return $self;
}

sub mime_type {
  my $self = shift;
  return $self->{'mime_type'};
}

sub set_mime_type {
  my ($self,$val) = @_;
  $self->{'mime_type'} = $val;
  return $self;
}

## no critic (Autoloading)
sub AUTOLOAD {
  my $self = shift;
  return $self;
}
## use critic

sub set_code {
  my ($self,$val) = @_;
  $self->{'code'} = $val;
  return $self;
}

sub set_sort_order {
  my ($self,@order) = @_;
  $self->{'sort_order'} = [@order];
  return $self;
}

1;
