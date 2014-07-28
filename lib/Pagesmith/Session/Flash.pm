package Pagesmith::Session::Flash;

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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Session);

use Apache2::Const qw(OK DECLINED);

sub new {
  my( $class, $r, $params ) = @_;
  my $self = $class->SUPER::new( $r, {( %{$params||{}}, 'type' => 'Flash', )} );
  $self->{'updated'} = 0;
  return $self;
}

## Some convenience methods...

## needs_ack => 'forever' - don't 'delete'

sub push_message {
  my ($self, $params ) = @_;

  $self->dumper( $params );

  my $id = $params->{'uuid'} || $self->safe_uuid;

  unless( exists $params->{'first'} && $params->{'first'} ) {
    unshift @{$self->data->{'message_order'}}, $id unless exists $self->data->{'messages'}{$id};
  } else {
    push    @{$self->data->{'message_order'}}, $id unless exists $self->data->{'messages'}{$id};
  }

  my $body = $params->{'body'}     || q(-);
     $body = sprintf '<p>%s</p>', $body unless q(<) eq substr $body, 0, 1;

  $self->data->{'messages'}{ $id } =  {
    'uuid'      => $id,
    'needs_ack' => $params->{'needs_ack'}|| q(),
    'level'     => $params->{'level'}    || 'info',
    'title'     => $params->{'title'}    || q(),
    'body'      => $body,
  };

  $self->{'updated'} = 1;
  return $self;
}

sub has_messages {
  my $self = shift;
  return 1 if @{$self->data->{'message_order'}};
  return 0;
}

sub get_messages {
  my $self = shift;
  return map { $self->data->{'messages'}{$_} } @{$self->data->{'message_order'}};
}

sub remove_message {
  my( $self, $msg, $force ) = @_;
  unless( ref $msg ) {
    return $self unless exists $self->{'data'}{'messages'}{$msg};
    $msg = $self->{'data'}{'messages'}{$msg};
  }
  return $self->_remove_message( $msg->{'uuid'} ) if $force;
  return $self->_remove_message( $msg->{'uuid'} ) unless $msg->{'needs_ack'} && $msg->{'needs_ack'} eq 'yes';
  return $self;
}

sub acknowledge_message {
  my ( $self,$id ) = @_;
  return $self unless exists $self->{'data'}{'messages'}{$id};
  $self->_remove_message( $id );
  return $self;
}

sub acknowledge_all_messages {
  my $self = shift;
  $self->_remove_message($_) foreach keys %{$self->data->{'messages'}};
  return $self;
}

sub _remove_message {
  my ( $self, $id ) = @_;
  return unless exists $self->data->{'messages'}{$id};

  $self->set_updated;

  my $msg = $self->data->{'messages'}{$id};
  delete $self->data->{'messages'}{$id};

  my $c = 0;

  foreach my $msg ( @{$self->data->{'message_order'}} ) {
    $c++;
    next unless $msg eq $id;
    splice @{$self->data->{'message_order'}},$c-1,1;
    last;
  }
  return $self;
}

sub set_updated {
  my $self = shift;
  $self->{'updated'} = 1;
  return $self;
}
sub is_updated {
  my $self = shift;
  return exists $self->{'updated'} ? $self->{'updated'} : 0;
}

sub clear_updated {
  my $self = shift;
  $self->{'updated'} = 0;
  return $self;
}

sub cleanup {
  my $self = shift;
  return OK unless $self->is_updated;
  if( $self->has_messages ) {
    $self->store;
  } else {
    $self->session_cache->unset;
  }
  return OK;
}

1;
