#!/usr/bin/perl

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

use File::Basename qw(dirname basename);
use English qw(-no_match_vars $PROGRAM_NAME);
use Cwd qw(abs_path);
use Readonly qw(Readonly);
use Getopt::Long qw(GetOptions);
use Time::HiRes qw(time);

my $start_time = time;

my $ROOT_PATH;
BEGIN {
  $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME)));
}

use lib "$ROOT_PATH/lib";

use Pagesmith::ConfigHash qw(set_site_key override_config docroot);
use Pagesmith::Adaptor;

my $key  = 'dev';
my $port = '80';
my $site = 'no-site';
my $verbose = 0;
my $quiet   = 0;

GetOptions(
  'key:s'   => \$key,
  'site:s'  => \$site,
  'verbose' => \$verbose,
  'quiet'   => \$quiet,
);

set_site_key( $site );
override_config( 'ConfigKey', $key ); ## Makes use live databases rather than dev!

my $dbh = Pagesmith::Adaptor->new( 'webcache' );

my $tables = $dbh->col( 'show tables' );
my $stats  = {};
my $now    = $dbh->now;

my $M = 0;
my $N = 0;
my $D = 0;

foreach my $table ( @{$tables} ) {
  next if $table eq 'site';
  $stats->{$table} = $dbh->row_hash( 'select count(*) as N, sum( expires_at < ? ) as M from '.$table, $now );
  $stats->{$table}{'D'} = $dbh->query( 'delete from '.$table.' where expires_at < ?', $now );
  $N += $stats->{$table}{'N'}||0;
  $M += $stats->{$table}{'M'}||0;
  $D += $stats->{$table}{'D'}||0;
}

exit if $quiet;

unless( $verbose ) {
  printf "\nEntries: %7d ; Deleted: %7d ; Actual: %7d - Time taken: %7.3f seconds\n\n", $N, $M, $D, time - $start_time;
  exit;
}

## no critic (CheckedSyscalls)
print "+---------+---------+---------+----------------------------------------+\n";
print "| Entries | Deleted | Actual  |Table\n";
print "+---------+---------+---------+----------------------------------------+\n";
foreach ( sort keys %{$stats} ) {
  next unless $stats->{$_}{'N'};
  printf "| %7d | %7d | %7d | %-38s |\n", map { $_||0} @{$stats->{$_}}{qw(N M D)}, $_;
}

print "+---------+---------+---------+----------------------------------------+\n";
printf "| %7d | %7d | %7d | %-38s |\n", $N, $M, $D, 'TOTAL';
print "+ --------+---------+---------+----------------------------------------+\n";

printf "\nTime taken: %7.3f seconds\n\n", time - $start_time;
## use critic
