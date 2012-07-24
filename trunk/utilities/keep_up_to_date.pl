#!/usr/bin/perl

## Keep server up to date
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

use HTML::Entities qw(encode_entities);

use Time::HiRes qw(time);
use English qw(-no_match_vars $PROGRAM_NAME $EVAL_ERROR $OUTPUT_AUTOFLUSH);
use Date::Format qw(time2str);
use File::Basename qw(dirname);
use Sys::Hostname::Long qw(hostname_long);
use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);
use Readonly qw(Readonly);
use Getopt::Long qw(GetOptions);

Readonly my $TO_MERGE       => 10;
Readonly my $UPDATE_NO      => 50;
Readonly my $DEF_SLEEP_TIME => 5;

my $ROOT_PATH;
BEGIN {
  $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME)));
}
use lib "$ROOT_PATH/lib";

use Pagesmith::Adaptor::PubQueue;
use Pagesmith::Utils::SVN::Support;
use Pagesmith::ConfigHash qw(set_site_key);

my $SLEEP_TIME     = $DEF_SLEEP_TIME;
my $MAX_RUNS       = 0;
my $DEBUG          = 0;
my $QUIET          = 0;
my $LOG_FILE       = "$ROOT_PATH/logs/svn-update.log";
my $ERROR_LOG_FILE = "$ROOT_PATH/logs/svn-error.log";

GetOptions(
  'verbose:+' => \$DEBUG,
  'quiet'     => \$QUIET,
  'sleep=f'   => \$SLEEP_TIME,
  'logfile:s' => \$LOG_FILE,
  'errorlog:s'=> \$ERROR_LOG_FILE,
  'runs:i'    => \$MAX_RUNS,
);

my $start_time = time;

set_site_key( 'no-site' ); ## This is so we get the dev pubqueue!

my $adap = Pagesmith::Adaptor::PubQueue->new;
my $support = Pagesmith::Utils::SVN::Support->new;

my $checkout_id = $adap->set_checkout( hostname_long, $ROOT_PATH );

my $run_number = 0;

$OUTPUT_AUTOFLUSH = 1;

## no critic (BriefOpen RequireChecked)
my $efh;
my $lfh;
unless( open $efh, '>>', $ERROR_LOG_FILE ) {
  die "CANNOT CREATE Error log file: $ERROR_LOG_FILE\n";
}
unless( open $lfh, '>>', $LOG_FILE ) {
  die "CANNOT CREATE Log file: $LOG_FILE\n";
}

## use critic;
my $time = gmtime;
printf {$efh}  "\n====================================\n\n  RESTARTED AT %s\n\n====================================\n\n", $time unless $QUIET;

my %externals = (
  'shared-content:/htdocs/core' => [],
  'www-genes2cognition-org:/htdocs/g2c' => [
    'www-genes2cognition-org:/htdocs-eurospin/g2c',
    'www-genes2cognition-org:/htdocs-synsys/g2c',
  ],
);

while( 1 ) {
  last if $MAX_RUNS && $run_number > $MAX_RUNS;
  my $loop_start_time = time;
  $run_number++;

  my $repositories = _find_repositories();
  my $l_time = gmtime;
  printf {$efh} "## RUN: %6d; time: %s\n", $run_number, $l_time if $DEBUG > 1;

  $adap->touch_checkout( );

  _debug_dump( $repositories )  if $DEBUG > 1;

  ## We need to do some additional code in here which will pick up changes that are in
  ## externals directives....

  foreach my $repos ( sort keys %{$repositories} ) {
    my $repos_id = $adap->set_repository( $repos );
    foreach my $branch ( sort keys %{$repositories->{$repos}} ) {
      my $branch_start_time = time;
      $adap->set_branch( $branch );
      $adap->touch_checkout_repository();
      my $outstanding = $adap->outstanding_updates();
      next unless @{$outstanding};
      my $revisions = {};
      my @paths = sort map { $_->{'path'} } @{$outstanding};
      my $tree  = {};

##  print join q(), map { sprintf "%6d : %s\n", $_->{'revision_no'}, $_->{'path'} } @{$outstanding};
      foreach my $path (@paths) {
        my @parts = split m{/}mxs, "-/$path";
        my $t = $tree;
        my $p;
        foreach( @parts ) {
          $t->{$_} ||= [ 0, {} ];
          $p = $t->{$_};
          $t = $t->{$_}[1];
        }
        $p->[0] = 1;
      }
      #print Dumper( $tree );
      _prune( $tree );
      my @minimal_paths = map { substr $_, 2 } _extract_paths( $tree, q() ); ## Extract the paths
      my $count = @minimal_paths;
      printf {$efh} "%s\n", Dumper( $repositories->{$repos}{$branch} ) if $DEBUG > 2;
      ## Now we have to perform the svn updates....
      my $success = _update_files( $support, $repositories->{$repos}{$branch}, @minimal_paths);
      $adap->touch_updates( [ map { $_->{'id'} } @{$outstanding} ]) if $success;

      my $r_time = gmtime;
      printf {$lfh} "success: %d time: %s; run: %7d;   updates: %5d;   time: %8.3f;   repos: %-30s;   branch: %-10s;\n",
        $success, $r_time, $run_number, $count, time-$branch_start_time, $repos, $branch if $DEBUG;
      ## and flag them as done in the database for this checkout!
      printf {$efh} "%s\n", Dumper ( \@minimal_paths ) if $DEBUG > 2;
    }
  }
  $adap->cleanup_checkout( );
  printf {$efh} "## RUN: %6d; time: %s; duration: %8.4f\n", $run_number, $time, time - $loop_start_time if $DEBUG;
  sleep $SLEEP_TIME;
}

sub _update_files {
## Perform the update commands
#@return (boolean) 1 if all updates succeed
  my( $l_support, $PATHS, @minimal_paths ) = @_;
  foreach my $dirh ( @{$PATHS} ) {
    my $path = $dirh->{'path'};
    my $dir  = $dirh->{'directory'};
    my @paths = map { ($path eq substr $_, 0, length $path) ? (substr $_,length $path): () } @minimal_paths;
    while( my @block = splice @paths, 0, $UPDATE_NO ) {
      my $command = sprintf 'svn up %s',
        join q( ), map { sprintf '%s/%s%s', $ROOT_PATH, $dir, $_  } @block;
      my $rv = eval {
        $l_support->read_from_process( $command );
      };
      if( $EVAL_ERROR ) {
        printf {$efh} "COMMAND: %s\n", $command;
        printf {$efh} "ERROR:   %s\n", $EVAL_ERROR;
        return 0;
      }
      printf {$lfh} $command,"\n" unless $QUIET;
    }
  }
  return 1;
}

sub _extract_paths {
## Convert directory tree back into an array of paths
#@ array of directory paths
  my( $tree, $path ) = @_;
  my @ret;
  foreach (keys %{$tree}) {
    if( $tree->{$_}[0] ) {
      push @ret, "$path/$_";
    } else {
      push @ret, _extract_paths( $tree->{$_}[1], "$path/$_" );
    }
  }
  return @ret;
}

sub _prune {
## Reduce the tree
## If a node is in the original file list its [0] value will be 1
##   therefore can ignore elements in tree (will update directory - don't need to update sub-directories/files)
## If the directory contains more than "TO_MERGE" elements then we also reduce the update to that directory
##   this reduces the complexity of the update command!
#@return nothing
  my $tree = shift;
  foreach ( keys %{$tree} ) {
    if($tree->{$_}[0] || scalar keys %{$tree->{$_}[1]} >= $TO_MERGE ) {
      $tree->{$_}[0] =1;
      $tree->{$_}[1] ={};
    } else {
      _prune( $tree->{$_}[1] );
    }
  }
  return;
}


sub _find_repositories {
## Search through the root directory (and sites subdirectory) to find
## any checkouts that we will be monitoring
#@return hashref of hashes of arrays - the keys being repository name and branch and the checkout directory
  my %repos;
  my $dh;
  my %paths = ( $ROOT_PATH => q(), "$ROOT_PATH/sites" => 'sites/' );
  foreach my $path (keys %paths) {
    next unless opendir $dh, $path;
    while( defined( my $dir = readdir $dh ) ) {
      next if $dir eq q(..) || $dir eq q(.);
      ## no critic (Filetest_f)
      if( -d "$path/$dir" && -d "$path/$dir/.svn" &&
          -f "$path/$dir/.svn/entries" &&
          open my $fh, q(<), "$path/$dir/.svn/entries" ) {
        while( my $line = <$fh> ) {
          chomp $line;
          if( $line =~ m{\Asvn\+ssh://web-svn.internal.sanger.ac.uk/repos/svn/([^/]+)/(trunk|live|staging)(.*)\Z}mxs ) {
            push @{ $repos{ $1 }{ $2 } }, { 'path' => $3, 'directory' => $paths{$path}.$dir };
            last;
          }
        }
        close $fh; ##no critic (RequireChecked)
      }
      ## use critic
    }
  }
  return \%repos;
}

sub _debug_dump {
  my $repositories = shift;
  foreach my $repos ( sort keys %{$repositories} ) {
    foreach my $branch ( sort keys %{$repositories->{$repos}} ) {
      printf {$efh} "Repos: %-30s; Branch: %-10s.\n", $repos, $branch;
    }
  }
  return;
}

