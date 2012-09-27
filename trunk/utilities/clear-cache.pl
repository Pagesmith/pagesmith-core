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
use IO::Handle;
use Readonly qw(Readonly);

STDOUT->autoflush(1); ## no critic (ExplicitInclusion)

Readonly my $BLOCK_SIZE => 100;

my $ROOT_PATH;
BEGIN {
  $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME)));
}

use lib "$ROOT_PATH/lib";

use Pagesmith::ConfigHash qw(set_site_key override_config);
use Pagesmith::Adaptor;

my $key = shift @ARGV;

$key ||= 'dev';

set_site_key( 'no-site' );
override_config( 'ConfigKey', $key ); ## Makes use live databases rather than dev!

my $dbh = Pagesmith::Adaptor->new( 'webcache' );

my $tables = $dbh->col( 'show tables' );
my $stats  = {};
my $now    = $dbh->now;

foreach my $table ( @{$tables} ) {
  next if $table eq 'site';
  $stats->{$table} = $dbh->row_hash( 'select count(*) as N, sum( expires_at < ? ) as M from '.$table, $now );
  $stats->{$table}{'D'} = $dbh->query( 'delete from '.$table.' where expires_at < ?', $now );
}

my $M = 0;
my $N = 0;
my $D = 0;

## no critic (CheckedSyscalls)
print "+---------+---------+---------+----------------------------------------+\n";
print "| Entries | Deleted | Actual  |Table\n";
print "+---------+---------+---------+----------------------------------------+\n";
foreach ( sort keys %{$stats} ) {
  printf "| %7d | %7d | %7d | %-38s |\n", map { $_||0} @{$stats->{$_}}{qw(N M D)}, $_;
  $N += $stats->{$_}{'N'}||0;
  $M += $stats->{$_}{'M'}||0;
  $D += $stats->{$_}{'D'}||0;
}

print "+---------+---------+---------+----------------------------------------+\n";
printf "| %7d | %7d | %7d | %-38s |\n", $N, $M, $D, 'TOTAL';
print "+ --------+---------+---------+----------------------------------------+\n";
## use critic
