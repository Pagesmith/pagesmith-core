package Pagesmith::Apache::Timer;

## Component
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

use Readonly qw(Readonly);
Readonly my $VERY_LARGE_TIME => 1_000_000;
Readonly my $CENT            => 100;
Readonly my $LEVEL           => 'quiet'; # (quiet,normal,noisy)

use Apache2::Const qw(OK DECLINED);
use English qw(-no_match_vars $PID);
use Time::HiRes qw(time);

my $child_started;
my $request_started;
my $requests;
my $total_time;
my $min_time;
my $max_time;
my $total_time_squared;

sub post_config_handler {
  return DECLINED if $LEVEL eq 'quiet';

  printf {*STDERR} "TI:   Start apache  %9d\n", $PID;
  return DECLINED;
}

sub child_init_handler {
  return DECLINED if $LEVEL eq 'quiet';

  $child_started = time;
  $requests      = 0;
  $total_time    = 0;
  $min_time      = $VERY_LARGE_TIME;
  $max_time      = 0;
  $total_time_squared  = 0;

  printf {*STDERR} "TI:   Start child   %9d\n", $PID;
  return DECLINED;
}

sub post_read_request_handler {
  my $r = shift;

  return DECLINED if $LEVEL eq 'quiet';

  $request_started = time;
  $requests++;

  return DECLINED unless $LEVEL eq 'noisy';

  printf {*STDERR} "TI:   Start request %9d - %4d              %s\n",
    $PID,
    $requests,
    $r->uri;
  return DECLINED;
}

sub log_handler {
  my $r             = shift;

  return DECLINED if $LEVEL eq 'quiet';

  my $request_ended = time;
  my $t             = $request_ended - $request_started;

  $total_time += $t;
  $min_time = $t if $t < $min_time;
  $max_time = $t if $t > $max_time;
  $total_time_squared += $t * $t;
  $r->subprocess_env->{'CHILD_COUNT'}  = $requests;
  $r->subprocess_env->{'SCRIPT_START'} = sprintf '%0.6f', $request_started;
  $r->subprocess_env->{'SCRIPT_END'}   = sprintf '%0.6f', $request_ended;
  $r->subprocess_env->{'SCRIPT_TIME'}  = sprintf '%0.6f', $t;

  return DECLINED unless $LEVEL eq 'noisy';

  printf {*STDERR} "TI:   End request   %9d - %4d %10.6f   %s\n", $PID, $requests, $t, $r->uri;
  return DECLINED;
}

sub child_exit_handler {
  return DECLINED if $LEVEL eq 'quiet';

  my $time_alive = time - $child_started;
  printf {*STDERR} "TI:   End child     %9d - %4d %10.6f %10.6f %7.3f%% %10.6f [%10.6f,%10.6f]\n",
    $PID,
    $requests,
    $total_time,
    $time_alive,
    $time_alive  ? $CENT * $total_time / $time_alive : 0,
    $requests    ? $total_time / $requests           : 0,
    $min_time,
    $max_time;
  return DECLINED;
}

1;
