package Pagesmith::Utils::SVN::Support;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

## Support class for SVN submissions
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

const my $SPACER    => q(=) x 78;
const my $LINE      => q(-) x 78;
const my $ONEBYTE   => 8;
const my $MASK      => 127;
const my $CORE_DUMP => 128;

use Time::HiRes qw(time);

use base qw(Pagesmith::Utils::Core);

sub log_trans {
  my( $self, $repos, $trans_id ) = @_;
  $repos =~ s{/}{-}mxsg;
  $self->{'log_file'} = "/www/tmp/svn-activity/transaction-$repos-$trans_id";
  return $self;
}

sub log_revision {
  my( $self, $repos, $rev_id ) = @_;
  $repos =~ s{/}{-}mxsg;
  $self->{'log_file'} = "/www/tmp/svn-activity/revision-$repos-$rev_id";
  return $self;
}

sub new {
  my $class = shift;
  my $self = {
    'message_sent' => 0,
    'start_time'   => time,
    'debug'        => 0,
    'log_file'     => undef,
    'log_fh'       => undef,
  };
  bless $self, $class;
  return $self;
}

sub turn_on_debug {
  my $self = shift;
  $self->{'debug'}=1;
  return $self;
}

sub turn_off_debug {
  my $self = shift;
  $self->{'debug'} = 0;
  return $self;
}

sub log_fh {
  my $self = shift;
  return unless $self->{'debug'} && $self->{'log_file'};
  unless( $self->{'log_fh'} ) {
    return unless open $self->{'log_fh'}, '>>', $self->{'log_file'};
  }
  return $self->{'log_fh'};
}

sub write_log {
  my( $self, $line ) = @_;
  if($self->log_fh) {
    printf {$self->log_fh} "Lapsed time: %10.4f - %s\n", time - $self->{'start_time'}, $line;
  }
  return $self;
}

sub clean_log {
  my $self = shift;
  if($self->{'log_fh'}) {
    $self->write_log( 'Closing log' );
    close $self->{'log_fh'}; ## no critic (RequireChecked)
  }
  return $self;
}
## Code for sending messages in "nice format"
sub clean_up {
  my $self = shift;
  printf {*STDERR} "\n%s\n\n", $SPACER if $self->{'message_sent'};
  return 1;
}

sub send_message {
  my( $self, $template, @params ) = @_;

  $self->{'message_sent'} = 1;
  printf {*STDERR} "\n%s\n\n%s\n", $SPACER, sprintf $template, @params;
  return $self;
}

## Quick wrapper around read_from_process specifically for svnlook
sub svnlook {
  my( $self, @command ) = @_;
  return $self->read_from_process( "/usr/bin/svnlook @command" );
}

sub push_changes {
  my( $self, $pqh, $changes, $time ) = @_;
  my $c = 0;
  my @entries;
  my $skipped = 0;
  foreach my $line (@{$changes}) {
    if( $line =~ m{\A\s{4}[(]from\s(.*?):r(\d+)[)]}mxs && !$skipped ) {
      $entries[-1]{ 'action'        } = 'copy';
      $entries[-1]{ 'copy_from'     } = $1;
      $entries[-1]{ 'copy_revision' } = $2;
    } elsif( $line =~ m{\A(..)[\s+]\s(.*)\Z}mxs ) {
      $skipped = 0;
      my($flag,$file) = ($1,$2);
      if( $file =~ m{\A(trunk|staging|live)/(.*)\Z}mxs ) {
        my $branch = $1;
        my $path   = $2;
        my $action = $flag eq 'A ' ? 'add'
                   : $flag eq 'D ' ? 'delete'
                   :                 'update'
                   ;
        push @entries, { 'branch' => $branch, 'action' => $action, 'path' => $path };
        $c++;
      } else {
        $skipped = 1;
      }
    }
  }
  my @new_entries;
  my $prev;
  foreach (@entries) {
    if( $prev && ($_->{'action'} eq 'add' || $_->{'action'} eq 'copy') && $prev->{'action'} eq 'delete' && $_->{'path'} eq $prev->{'path'} ) {
      $new_entries[-1]{'action'} = $_->{'action'} eq 'copy' ? 'copyreplace' : 'replace';
      next;
    }
    push @new_entries, $_;
    $prev = $_;
  }
  foreach( @new_entries ) {
    $pqh->create_entry( $_->{'action'}, $_->{'path'}, $_->{'copy_from'}, $_->{'copy_revision'}, $_->{'branch'}, $time );
  }
  return $c;
}

1;
