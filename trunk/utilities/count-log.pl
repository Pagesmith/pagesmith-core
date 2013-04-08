#!/usr/bin/perl

## Tail error/access logs
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

use English qw(-no_match_vars $PROGRAM_NAME $ERRNO);

use Getopt::Long qw(GetOptions);
use File::Basename qw(dirname basename);
use Cwd qw(abs_path);
use POSIX qw(strftime floor);

use Const::Fast qw(const);
const my $MINUTE   => 60;
const my $INTERVAL => 5 * $MINUTE; ## 10 minutes...
const my $MAXDUR   => 3;
const my $TOTDUR   => 4;

my $path    = dirname(dirname(abs_path($PROGRAM_NAME)));
my $system  = basename($path);

my $lr = $path.'/logs';
## If it is www-.... then look for
$lr = "/www/tmp/$1/logs" if $path =~ m{^\/www\/(([-\w]+\/)?www-\w+)}mxs;
my $al = "$lr/diagnostic.log";

my $events;

if( open my $fh, q(<), $al ) {
  while(<$fh>) {
    if( m{"[ ](\d+[.]\d+)/(\d+[.]\d+)[ ]\[}mxs ) {
      my $dur = $2 - $1;
      push @{$events->{$1}{'s'}}, $dur;
      push @{$events->{$2}{'e'}}, $dur;
    }
  }
  close $fh; ## no critic (RequireChecked)
}

my @event_times = sort { $a <=> $b } keys %{$events};
my %intervals;
my $n_req   = 0;
my $max_dur = 0;
my $max_req = 0;
my $max_time = 0;
my $max_dur_time = 0;
foreach (@event_times) {
  my $st = exists $events->{$_}{'s'} ? scalar @{$events->{$_}{'s'}} : 0;
  my $fi = exists $events->{$_}{'e'} ? scalar @{$events->{$_}{'e'}} : 0;
  $n_req += $st - $fi;
  my @time = localtime $_;
  my $s_past_hour = $time[0] + $MINUTE * $time[1];
  my $s_block     = floor( $s_past_hour / $INTERVAL ) * $INTERVAL;
  $time[0] = $s_block % $MINUTE;
  $time[1] = ($s_block - $time[0])/$MINUTE;
  my $time = strftime( q(%Y-%m-%d %H:%M:%S), @time );

  if( $n_req > $max_req ) {
    $max_req  = $n_req;
    $max_time = $_;
  }
  if( exists $intervals{$time} ) {
    $intervals{$time}[0] = $n_req if $n_req > $intervals{$time}[0];
    $intervals{$time}[1] += $st;
    $intervals{$time}[2] += $fi;
  } else {
    $intervals{$time} = [ $n_req, $st, $fi, 0, 0 ];
  }
  foreach my $dur ( @{$events->{$_}{'s'}||[]} ) {
    $max_dur = $dur if $dur > $max_dur;
    $intervals{$time}[$MAXDUR] =$dur if $dur > $intervals{$time}[$MAXDUR];
    $intervals{$time}[$TOTDUR]+=$dur;
  }
}

foreach (sort keys %intervals) {
  my $diff = $intervals{$_}[1]-$intervals{$_}[2];
  printf "%s\t%5d\t%5d\t%5d\t%12.5f\t%12.5f\t\t%s\n",
    $_,
    @{$intervals{$_}}[0,1,2,$MAXDUR],
    $intervals{$_}[1] ? $intervals{$_}[$TOTDUR]/$intervals{$_}[1] : 0,
    $diff ? sprintf '%s%d', $diff < 0 ? q(-):q(+), abs $diff : q();
}

printf {*STDERR} "\nMax requests... %d \@ %s\n\n", $max_req, strftime( q(%Y-%m-%d %H:%M:%S), localtime $max_time );
