package Pagesmith::Form::Message;

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

use base qw(Pagesmith::Support);

use HTML::Entities qw(encode_entities);

my %LEVELS = qw(
  error  -1000
  warn    -500
  msg     -100
  info       0
);

sub new {
  my( $class, $params ) = @_;
  my $level = 'error';
  $level = $params->{'level'} if exists $params->{'level'} && exists $LEVELS{ $params->{'level'} };
  my $self = {
    'raw'     => $params->{'raw'}||q(),
    'text'    => $params->{'text'},
    'level'   => $params->{'level'} || 'error',
  };

  bless $self, $class;
  return $self;
}

sub num_level {
  my $self = shift;
  return exists $LEVELS{ $self->{'level'} } ? $LEVELS{ $self->{'level'} } : 0;
}

sub level {
  my $self = shift;
  return $self->{'level'};
}

sub raw {
  my $self = shift;
  return $self->{'raw'};
}

sub html {
  my $self = shift;
  return $self->{'raw'} ? $self->{'text'} : encode_entities( $self->{'text'});
}

sub text {
  my $self = shift;
  return $self->{'text'};
}

1;
