package Pagesmith::Adaptor::PubQueue;

## Embryonic pub queue adaptor...
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

use base qw(Pagesmith::BaseAdaptor);

use English qw(-no_match_vars $PID);

my %VALID_BRANCHES = qw(trunk 1 staging 1 live 1);

sub new {
  my( $class, $r ) = @_;
  my $self = $class->SUPER::new( $r );

  $self->{'user_id'      } = undef;
  $self->{'repository_id'} = undef;
  $self->{'revision_no'  } = undef;
  $self->{'checkout_id'  } = undef;
  return $self;
}

sub connection_pars {
  return 'pubqueue';
}

  ## no critic (ManyArgs)
sub create_entry {
  my( $self, $action, $path, $old_path, $old_revision_no, $branch, $time ) = @_;
  $old_path        = q()               unless defined $old_path;
  $old_revision_no = 0                 unless defined $old_revision_no;
  $branch          = $self->{'branch'} unless defined $branch;
  $time            = $self->now        unless defined $time;
  ## no critic (ImplicitNewlines)
  return $self->query( 'insert into filechange (repository_id,branch,path,revision_no,old_path,old_revision_no,committed_by,committed_at,action)
    values(?,?,?,?,?,?,?,?,?)',
    $self->{'repository_id'},
    $branch,
    $path,$self->{'revision_no'},
    $old_path, $old_revision_no,
    $self->{'user_id'}, $time, $action );
  ## use critic
}

sub set_revision {
  my( $self, $revision_no ) = @_;
  return $self->{'revision_no'} = $revision_no;
}

sub branch {
  my $self = shift;
  return $self->{'branch'};
}

sub set_branch {
  my( $self, $branch ) = @_;
  $branch = 'trunk' unless exists $VALID_BRANCHES{$branch};
  return $self->{'branch'} = $branch;
}

sub user_id {
  my $self = shift;
  return $self->{'user_id'};
}

sub checkout_id {
  my $self = shift;
  return $self->{'checkout_id'};
}

sub revision_no {
  my $self = shift;
  return $self->{'revision_no'};
}

sub repository_id {
  my $self = shift;
  return $self->{'repository_id'};
}

sub set_user {
  my( $self, $user, $name ) = @_;
  return $self->{'user_id'} = $self->sv( 'select id from user where code = ?', $user ) ||
    $self->insert( 'insert into user (code,name) values (?,?)', 'user', 'code', $user, $name );
}

sub set_repository {
  my( $self, $repository ) = @_;
  $repository =~ s{\A/repos/svn/}{}mxs;
  return $self->{'repository_id'} = $self->sv( 'select id from repository where code = ?', $repository ) ||
    $self->insert( 'insert into repository (code) values (?)', 'repository', 'code', $repository );
}

sub set_checkout {
  my( $self, $server, $path ) = @_;
  my $co_id = $self->sv( 'select id from checkout where server = ? and root_path = ?',
    $server, $path );
  unless( $co_id ) {
    $self->query( 'insert ignore into checkout (server,root_path) values(?,?)',
       $server, $path );
    $co_id = $self->sv( 'select id from checkout where server = ? and root_path = ?',
      $server, $path );
  }
  return $self->{'checkout_id'} = $co_id;
}

sub touch_updates {
  my( $self, $ids ) = @_;
  my $now = $self->now;
  my $sql= sprintf 'insert ignore filechange_checkout (filechange_id,checkout_id,datetime) values %s',
    join q(,), map { q((?,?,?)) } @{$ids};
  return $self->query( $sql, map { ($_, $self->{'checkout_id'}, $now) } @{$ids} );
}

sub touch_checkout_repository {
  my $self = shift;
  if( my $status = $self->sv( 'select status from checkout_repository where repository_id = ? and checkout_id = ? and branch = ?',
    $self->repository_id, $self->checkout_id, $self->branch ) ) {
    $self->query( 'update checkout_repository set updated_at = ?, status = "active" where repository_id = ? and checkout_id = ? and branch = ?',
      $self->now, $self->repository_id, $self->checkout_id, $self->branch ) unless $status eq 'active';
  } else {
    $self->query( 'insert ignore into checkout_repository (repository_id,checkout_id,branch,status,created_at) values(?,?,?,"active",?)',
      $self->repository_id, $self->checkout_id, $self->branch, $self->now );
  }
  return;
}

sub get_all_repositories {
  my $self = shift;
  return $self->col( 'select code from repository order by code' );
}

sub touch_checkout {
  my $self = shift;
  return $self->query(
    'update checkout_repository set status = "touched", updated_at = ? where checkout_id = ?',
    $self->now, $self->checkout_id,
  );
}


sub cleanup_checkout {
  my $self = shift;
  return $self->query(
    'update checkout_repository set status = "inactive", updated_at = ? where checkout_id = ? and status = "touched"',
    $self->now, $self->checkout_id,
  );
}

sub outstanding_updates {
  my( $self ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash( 'select f.id,f.path,f.action,f.revision_no
   from filechange f left join filechange_checkout fc on
        f.id = fc.filechange_id and fc.checkout_id=?
  where isnull(fc.filechange_id) and f.repository_id=? and
        f.branch = ?
  order by f.id', $self->checkout_id, $self->repository_id, $self->branch,
  );
  ## use critic
}
1;

