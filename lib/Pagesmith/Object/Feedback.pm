package Pagesmith::Object::Feedback;

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
  my($class,$adaptor,$feedback_data) = @_;
     $feedback_data    ||= {};
  my $self    = {
    'adaptor'    => $adaptor,
    'page'       => $feedback_data->{'page'},
    'created_at' => $feedback_data->{'created_at'},
    'created_by' => $feedback_data->{'created_by'},
    'comment'    => $feedback_data->{'comment'},
    'ip'         => $feedback_data->{'ip'},
    'useragent'  => $feedback_data->{'useragent'},
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

sub comment {
  my $self = shift;
  return $self->{'comment'};
}

sub ip {
  my $self = shift;
  return $self->{'ip'};
}

sub useragent {
  my $self = shift;
  return $self->{'useragent'};
}

sub store {
  my $self = shift;
  return $self->{'adaptor'}->store($self);
}
1;
