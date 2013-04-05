package Pagesmith::Form::Root;

## Handles submission of Form object
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

use Const::Fast qw(const);
use base qw(Pagesmith::Support);

## Used by the "logic code"

const my $DEFAULT_TYPE   => 'all';
const my $DEFAULT_ACTION => 'enable';
my %actions = map { ($_=>1) } qw(disable enable required optional);
my %types   = map { ($_=>1) } qw(all any not_all none);

## Logic code!
sub add_logic {
  my( $self, $action, $type, @dfns ) = @_;
  push @{$self->{'logic'}}, {
    'action'      => exists $actions{$action||q()} ? $action : $DEFAULT_ACTION,
    'type'        => exists   $types{  $type||q()} ? $type   : $DEFAULT_TYPE,
    'conditions'  => \@dfns,
  };
  return $self;
}

sub clear_logic {
  my $self = shift;
  $self->{'logic'} = [];
  return $self;
}

sub has_logic {
  my $self = shift;
  return @{$self->{'logic'}||[]} ? 1: 0;
}

sub logic {
  my $self = shift;
  return $self->{'logic'}||[];
}

sub enable {
  my $self = shift;
  $self->{'enabled'} = 'yes';
  return $self;
}

sub disable_by_same_stage {
  my $self = shift;
  $self->{'enabled'} = 'same';
  return $self;
}

sub disable {
  my $self = shift;
  $self->{'enabled'} = 'no';
  return $self;
}

sub enabled {
  my $self = shift;
  return $self->{'enabled'} eq 'yes';
}

sub disabled {
  my $self = shift;
  return $self->{'enabled'} ne 'yes';
}

sub set_required {
  my $self = shift;
  $self->{'required'} = 'yes';
  return $self;
}

sub set_optional {
  my $self = shift;
  $self->{'required'} = 'no';
  return $self;
}

sub is_required {
  my $self = shift;
  return $self->{'required'} eq 'yes';
}

sub is_optional {
  my $self = shift;
  return $self->{'required'} eq 'no';
}

1;
