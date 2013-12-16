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

use Const::Fast qw(const);
const my $VERY_LARGE_TIME => 1_000_000;
const my $CENT            => 100;
const my $LEVEL           => 'normal'; # (quiet,normal,noisy)

use Apache2::Const qw(OK DECLINED);
use Apache2::SizeLimit;
use English qw(-no_match_vars $PID);
use Time::HiRes qw(time);

my $child_started;
my $request_started;
my $requests;
my $total_time;
my $min_time;
my $max_time;
my $total_time_squared;
my $size;
my $shared;
my $unshared;

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
  ($size,$shared,$unshared) = Apache2::SizeLimit->_check_size(); ##no critic(PrivateSubs)  ## non-PS private fn
  binmode STDERR, ':utf8';  ## no critic (EncodingWithUTF8Layer)
  printf {*STDERR} "TI:   Start child   %9d\n", $PID;
  return DECLINED;
}

sub post_read_request_handler {
  my $r = shift;

  return DECLINED if $LEVEL eq 'quiet';

  $request_started = time;
  $requests++;

  $r->subprocess_env->{'CHILD_COUNT'}    = $requests;
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
  my ($new_size, $new_shared, $new_unshared) = Apache2::SizeLimit->_check_size(); ##no critic(PrivateSubs)

  my $z = $r->next || $r;
  $z->subprocess_env->{'SCRIPT_START'}   = sprintf '%0.6f', $request_started;
  $z->subprocess_env->{'SCRIPT_END'}     = sprintf '%0.6f', $request_ended;
  $z->subprocess_env->{'SCRIPT_TIME'}    = sprintf '%0.6f', $t;

  $z->subprocess_env->{'SIZE'}           = $new_size;
  $z->subprocess_env->{'SHARED'}         = $new_shared;
  $z->subprocess_env->{'UNSHARED'}       = $new_unshared;
  $z->subprocess_env->{'DELTA_SIZE'}     = $new_size - $size;
  $z->subprocess_env->{'DELTA_SHARED'}   = $new_shared - $shared;
  $z->subprocess_env->{'DELTA_UNSHARED'} = $new_unshared - $unshared;

  $size     = $new_size;
  $shared   = $new_shared;
  $unshared = $new_unshared;

  return DECLINED unless $LEVEL eq 'noisy';

  printf {*STDERR} "TI:   End request   %9d - %4d %10.6f   %s\n", $PID, $requests, $t, $r->uri;
  return DECLINED;
}

sub child_exit_handler {
  return DECLINED if $LEVEL eq 'quiet';

  my $time_alive = time - $child_started;
  printf {*STDERR} "TI:   End child     %9d - %4d %10.6f %10.6f %7.3f%% %10.6f [%10.6f,%10.6f] %10d %10d %10d\n",
    $PID,
    $requests,
    $total_time,
    $time_alive,
    $time_alive  ? $CENT * $total_time / $time_alive : 0,
    $requests    ? $total_time / $requests           : 0,
    $min_time,
    $max_time,
    $size,
    $shared,
    $unshared,
    ;
  return DECLINED;
}

1;
