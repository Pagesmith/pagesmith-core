package Pagesmith::Object::Event;

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
  my($class,$adaptor,$event_data) = @_;
     $event_data    ||= {};
  my $self    = {
    'adaptor'    => $adaptor,
     %{$event_data},
#    'created_at' => $event_data->{'created_at'},
#    'created_by' => $event_data->{'created_by'},
#    'updated_at' => $event_data->{'updated_at'},
#    'updated_by' => $event_data->{'updated_by'},
  };
  bless $self, $class;
  return $self;
}

sub page {
  my $self = shift;
  return $self->{'page'};
}

sub created_at {
  my $self = shift;
  return $self->{'created_at'};
}

sub created_by {
  my $self = shift;
  return $self->{'created_by'};
}

sub updated_at {
  my $self = shift;
  return $self->{'created_at'};
}

sub updated_by {
  my $self = shift;
  return $self->{'created_by'};
}

## Title of talk and abstract....
sub set_title {
  my($self, $value) = @_;
  $self->{'title'} = $value;
  return $self;
}

sub set_url {
  my($self, $value) = @_;
  $self->{'url'} = $value;
  return $self;
}

sub set_precis {
  my($self, $value) = @_;
  $self->{'precis'} = $value;
  return $self;
}

sub title {
  my $self = shift;
  return $self->{'title'};
}

sub url {
  my $self = shift;
  return $self->{'url'};
}

sub precis {
  my $self = shift;
  return $self->{'precis'};
}

## Date/times
sub set_start_date {
  my($self, $value) = @_;
  $self->{'start_date'} = $value;
  return $self;
}

sub set_end_date {
  my($self, $value) = @_;
  $self->{'end_date'} = $value;
  return $self;
}

sub set_start_time {
  my($self, $value) = @_;
  $self->{'start_time'} = $value;
  return $self;
}

sub set_end_time {
  my($self, $value) = @_;
  $self->{'end_time'} = $value;
  return $self;
}

sub set_regclose_date {
  my($self, $value) = @_;
  $self->{'regclose_date'} = $value;
  return $self;
}

sub start_date {
  my $self = shift;
  return $self->{'start_date'};
}

sub end_date {
  my $self = shift;
  return $self->{'end_date'};
}

sub start_time {
  my $self = shift;
  return $self->{'start_time'};
}

sub end_time {
  my $self = shift;
  return $self->{'end_time'};
}

sub regclose_date {
  my $self = shift;
  return $self->{'regclose_date'};
}

## Host...
sub set_host {
  my($self, $value) = @_;
  $self->{'host'} = $value;
  return $self;
}

sub host {
  my $self = shift;
  return $self->{'host'};
}

## Speakers and affiliation
sub set_title_id {
  my($self, $value) = @_;
  $self->{'title_id'} = $value;
  return $self;
}

sub set_firstname {
  my($self, $value) = @_;
  $self->{'firstname'} = $value;
  return $self;
}

sub set_lastname {
  my($self, $value) = @_;
  $self->{'lastname'} = $value;
  return $self;
}

sub set_affiliation {
  my($self, $value) = @_;
  $self->{'affiliation'} = $value;
  return $self;
}

sub title_id {
  my $self = shift;
  return $self->{'title_id'};
}

sub speaker_title {
  my $self = shift;
  return $self->{'speaker_title'};
}

sub firstname {
  my $self = shift;
  return $self->{'firstname'};
}

sub lastname {
  my $self = shift;
  return $self->{'lastname'};
}

sub affiliation {
  my $self = shift;
  return $self->{'affiliation'};
}


## Meta information

sub set_category_id {
  my($self, $value) = @_;
  $self->{'category_id'} = $value;
  return $self;
}

sub set_type_id {
  my($self, $value) = @_;
  $self->{'type_id'} = $value;
  return $self;
}

sub set_location_id {
  my($self, $value) = @_;
  $self->{'location_id'} = $value;
  return $self;
}

sub category_id {
  my $self = shift;
  return $self->{'category_id'};
}

sub category {
  my $self = shift;
  return $self->{'category'};
}

sub type_id {
  my $self = shift;
  return $self->{'type_id'};
}

sub type {
  my $self = shift;
  return $self->{'type'};
}

sub brand_id {
  my $self = shift;
  return $self->{'brand_id'};
}

sub event_id {
  my $self = shift;
  return $self->{'event_id'};
}

sub set_event_id {
  my($self, $value) = @_;
  $self->{'event_ id'} = $value;
  return $self;
}

sub brand_code {
  my $self = shift;
  return $self->{'brand_code'};
}

sub brand {
  my $self = shift;
  return $self->{'brand'};
}

sub location_id {
  my $self = shift;
  return $self->{'location_id'};
}

sub location {
  my $self = shift;
  return $self->{'location'};
}

sub status {
  my $self = shift;
  return $self->{'status'};
}

sub set_status {
  my($self, $value) = @_;
  $self->{'status'} = $value;
  return $self;
}
sub store {
  my $self = shift;
  return $self->{'adaptor'}->store($self);
}

1;
