package Pagesmith::Object::PubQueue::Job;

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

use base qw(Pagesmith::Object::PubQueue);

use English qw(-no_match_vars $PID);

my $ALLOWED_TRANSITIONS = {
  'archived'   => {},
  'done'       => { 'archived' => 1 },
  'failed'     => { 'pending' => 1, 'archived' => 1 },
  'dropped'    => { 'archived' => 1 },
  'deleted'    => { 'archived' => 1 },
  'pending'    => { 'processing' => 1, 'dropped' => 1, 'deleted' => 1 },
  'processing' => { 'done' => 1, 'failed' => 1 },
};

sub init {
  my( $self, $href ) =@_;
  $self->super_init();
  $self->{ '_status'   } = $href->{'status'}          || q();
  $self->{ '_action'   } = $href->{'code'}            || q();
  $self->{ '_id'       } = $href->{'job_id'}          || 0;
  $self->{ '_pars'     } = $href->{'parameters'}      || q();
  $self->{ '_embargo'  } = $href->{'embargoed_until'} || 0;
  $self->{ '_priority' } = $href->{'priority'}        || 0;
  return;
}

sub id {
  my $self = shift;
  return  $self->{'_id'};
}

sub action {
  my $self = shift;
  return  $self->{'_action'};
}

sub pars {
  my $self = shift;
  return  $self->{'_pars'};
}

sub priority {
  my $self = shift;
  return  $self->{'_priority'};
}

sub embargo {
  my $self = shift;
  return  $self->{'_embargo'};
}

sub status {
  my $self = shift;
  return $self->{'_status'};
}

sub create {
  my( $self ) = @_;
  return if $self->id; ## Already created;
  $self->{'_status'} = 'pending';
  my $jobtype_id = $self->sv( 'select jobtype_id from jobtype where code=?',$self->action );
  ##no critic (ImplicitNewlines)
  my $flag = $self->query( '
    insert into job
       set jobtype_id = ?,
           status = "pending", created_at = ?, created_by =?,
           embargoed_until = ?, priority = ?,
           pid = ?, parameters = ?',
    $jobtype_id,
    $self->now(), $self->user_id, $self->embargo, $self->priority,
    $self->pid, $self->pars,
  );
  ##use critic (ImplicitNewlines)
  if( $flag > 0 ) {
    $self->id = $self->last_id;
    $self->audit( 'Created' );
  }
  return;
}

sub audit {
  my( $self, $msg ) = @_;
  return $self->_audit( $msg, $self->status, $self->id );
}

sub _audit {
  my( $self, $msg, $status, @ids ) = @_;

  foreach( @ids ) {
    ##no critic (ImplicitNewlines)
    return $self->query( '
      insert into audit
                  ( job_id, status, created_at, created_by, pid, notes )
            values( ?,      ?,      ?,          ?,          ?,   ? )',
      $_, $status, $self->now, $self->user_id, $self->pid, $msg,
    );
    ##use critic (ImplicitNewlines)
  }
  return;
}

sub update_status {
  my( $self, $new_status ) = @_;
  return 0 unless $ALLOWED_TRANSITIONS->{ $self->status }{ $new_status };
  ##no critic (ImplicitNewlines)
  $self->query( '
    update job
       set status = ?, updated_at = ?, updated_by = ?
     where job_id = ?, pid = ?',
    $new_status, $self->now, $self->user_id, $self->id, $self->pid,
  );
  ##use critic (ImplicitNewlines)
  $self->{'_status'} = $new_status;
  $self->audit( 'Changed status' );
  return 1;
}

sub run {
  my $self = shift;
  my $method = 'run_' . $self->action;
  return $self->$method || 1;
}

sub run_shutdown {
  my $self = shift;
  $self->query( 'lock tables job write, audit write' );
  my $job_ids = $self->col(
    'select job_id from job where status = "pending" and job_id != ? and jobtype_id = 1',
    $self->id,
  );
  if( $job_ids ) {
    ##no critic (ImplicitNewlines)
    $self->query('
      update job
         set status = "dropped", updated_at = ?, updated_by = ?, pid = ?
       where jobtype_id = 1 and job_id != ? and status = "pending"',
      $self->now, $self->user_id, $PID, $self->id,
    );
    ##use critic (ImplicitNewlines)
    $self->_audit( 'Superceded by '.$self->id, 'dropped', @{$job_ids} );
  }
  $self->update_status( 'done' );
  return 0;
}

1;
