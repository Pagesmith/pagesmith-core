package Pagesmith::Object::PubQueue;

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

use English qw(-no_match_vars $PID);

sub super_init {
  my $self = shift;
  $self->{'_pid'} = $PID;
  return;
}

sub pid     {
  my $self = shift;
  return $self->{'_pid'};
}            #@access/ro

sub user_id {
  my $self = shift;
  return $self->{'_adpt'}->user_id;
}    #@access/ro
1;
