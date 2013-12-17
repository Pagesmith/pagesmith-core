#!/usr/bin/perl

## Keeps a serve up to date - BUT not using keep uptodate - basically runs svn up on each repository

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
use feature qw(switch);

use version qw(qv); our $VERSION = qv('0.1.0');

use English qw(-no_match_vars $PROGRAM_NAME $ERRNO $EVAL_ERROR $OUTPUT_AUTOFLUSH);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Const::Fast qw(const);

const my $SLEEP         => 10;
const my $TOUCH_DIR     => '/www/tmp/svn-touch/';
const my %EXTRA_MIRRORS => (
  '/repos/svn/other/frontend-config' => [
    qw( svn+psssh://svn-user@websvn-europe.sanger.ac.uk/repos/svn/other
        svn+psssh://svn-user@websvn-uswest.sanger.ac.uk/repos/svn/other ) ],
  '/repos/svn/other/web-utilities' => [
    qw( svn+psssh://svn-user@websvn-europe.sanger.ac.uk/repos/svn/other
        svn+psssh://svn-user@websvn-uswest.sanger.ac.uk/repos/svn/other ) ],
);
my $ROOT_PATH;
BEGIN {
  $ROOT_PATH = dirname(dirname(dirname(abs_path($PROGRAM_NAME))));
}
use lib "$ROOT_PATH/lib";

use Pagesmith::Root;
use Pagesmith::Utils::SVN::Config;
use Pagesmith::ConfigHash qw(set_site_key);

touch("$TOUCH_DIR/_SYNC_IN_PROGRESS_");

set_site_key( 'no-site' );

my $config  = Pagesmith::Utils::SVN::Config->new( $ROOT_PATH );

exit 0 unless $config;

my $root = Pagesmith::Root->new;

my @repos = keys %{$config->{'repositories'}};
foreach my $repos (@repos) {
  my ( $type, $site ) = @{$config->{'repositories'}{$repos} };
  my $mirrors = $config->{'raw'}{$type}{$site}{'mirrors'};
  next unless $mirrors && @{$mirrors};
  foreach ( @{$mirrors} ) {
    print "##REPOS: $_/$repos\n"; ## no critic (RequireChecked)
    my $out = $root->run_cmd( [ qw(svnsync synchronize --non-interactive), $_.q(/).$repos ] );
    dump_out( $out );
  }
}
foreach my$repos (keys %EXTRA_MIRRORS) {
  my $mirrors = $EXTRA_MIRRORS{$repos};
  (my $repos_name = $repos ) =~ s{.*/}{}mxs;
  foreach ( @{$mirrors} ) {
    print "##REPOS: $_/$repos_name\n"; ## no critic (RequireChecked)
    my $out = $root->run_cmd( [ qw(svnsync synchronize --non-interactive), "$_/$repos_name" ] );
    dump_out( $out );
  }
}

while(1) {
  my $die_after = 0;
  if( opendir my $dh, $TOUCH_DIR ) {
    my @files = grep { m{\A__.*}mxs } readdir $dh;
    foreach my $fn (@files) {
      if( $fn eq q(__) ) {
        $die_after = 1;
        next;
      }
      (my $repos = $fn ) =~ s{__}{/}mxsg;
      warn "REPOS $repos\n";
      $config->set_repos( $repos );
      my $mirrors = $config->info('mirrors');
      unless( $mirrors && @{$mirrors} ) {
        $mirrors = $EXTRA_MIRRORS{$repos} if exists $EXTRA_MIRRORS{$repos};
      }
      foreach my $m (@{$mirrors||[]}) {
        my $repos_name = $config->repos;
        unless( $repos_name ) {
          ( $repos_name = $repos ) =~ s{.*/}{}mxs;
        }
        print "##REPOS: $m/$repos_name\n"; ## no critic (RequireChecked)
        my $out = $root->run_cmd( [ qw(svnsync synchronize --non-interactive), "$m/$repos_name" ] );
        dump_out( $out );
      }
      unlink "$TOUCH_DIR/$fn";
    }
  } else {
    die "can't opendir $TOUCH_DIR: $ERRNO\n";
  }
  if( $die_after ) {
    unlink "$TOUCH_DIR/__";
    unlink "$TOUCH_DIR/_SYNC_IN_PROGRESS_";
    die "TOUCH FILE FOUND\n";
  }
  sleep $SLEEP;
}

sub dump_out {
  my $out = shift;
  delete $out->{'command'};
  print $root->raw_dumper( $out ),"\n"; ## no critic (RequireChecked)
  print "\n"; ## no critic (RequireChecked)
  return;
}

sub touch {
  my $fn = shift;
  if( -e $fn ) {
    return 1;
  } elsif( open my $fh, q(>), $fn ) {
    close $fh; ## no critic (RequireChecked)
    return 1;
  }
  return 0;
}
