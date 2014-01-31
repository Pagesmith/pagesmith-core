package Pagesmith::Object;

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

sub flag_as_partial {
  my $self = shift;
  $self->{'is_partial'} = 1;
  return $self;
}

sub flag_as_full {
  my $self = shift;
  $self->{'is_partial'} = 0;
  return $self;
}

sub is_partial {
  my $self = shift;
  return $self->{'is_partial'};
}

1;
