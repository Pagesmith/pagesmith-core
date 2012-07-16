package Pagesmith::Apache::Errors;

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
Readonly my $ERROR_WIDTH         => 160;
Readonly my $STACKTRACE_MAXDEPTH => 10;
Readonly my $STACKTRACE_LEVEL    => 'warn';

use Apache2::Const qw(OK DECLINED);
use English qw(-no_match_vars $PID);
use Time::HiRes qw(time);

use Pagesmith::Message;
use JSON::XS;

sub init_error {
  my $r = shift;
  my $messages = [];
  $r->pnotes( 'errors', $messages );
  ## no critic (LocalizedPunctuationVars)
  $SIG{'__WARN__'} = sub { my $msg = $_[0]; my $flag = ($msg =~ s{\A!raw!}{}mxs); push @{$messages}, Pagesmith::Message->new( $msg, 'warn', $flag ); };
  ## use critic
  return DECLINED;
}

sub dump_to_log {
  my $r = shift;

  my $messages = $r->pnotes( 'errors' )||[];

  my $json = JSON::XS->new->utf8;

  push @{$messages}, @{$r->next->pnotes('errors')||[]} if $r->next;

  my $phpe = $r->notes->get('errors');
  if( $phpe ) {
    push @{$messages}, map { Pagesmith::Message->from_php( $_ ) } @{ $json->decode($phpe) ||[] };
    $r->notes->unset('errors');
  }
  if( $r->next ) {
    my $l_phpe = $r->next->notes->get('errors');
    if( $l_phpe ) {
      push @{$messages}, map { Pagesmith::Message->from_php( $_ ) } @{ $json->decode($l_phpe) ||[] };
      $r->next->notes->unset('errors');
    }
  }
  return unless @{$messages};

  my $line = q(-) x $ERROR_WIDTH;
  my $bold = q(=) x $ERROR_WIDTH;
  ## no critic (CheckedSyscalls)
  print {*STDERR} "$bold\n";
  my $IP = $r->headers_in->{ 'X-Forwarded-For' } || $r->connection->remote_ip;
  printf {*STDERR} "PID: %d; Hostname: %s; Request: %s; IP: %s; Time: %s.\n",
    $PID, $r->hostname, $r->unparsed_uri, $IP, q().localtime;
  foreach ( @{$messages} ) {
    print {*STDERR} join "\n", $line, $_->render_txt($STACKTRACE_MAXDEPTH,$STACKTRACE_LEVEL),q();
  }
  print {*STDERR} "$bold\n\n";
  ## use critic;

  return DECLINED;
}

1;
