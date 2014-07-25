package Pagesmith::Apache::Errors;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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
const my $ERROR_WIDTH         => 160;
const my $STACKTRACE_MAXDEPTH => 10;
const my $STACKTRACE_LEVEL    => 'warn';

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
  $SIG{'__WARN__'} = sub {
    my $msg = $_[0];
    my $flag = 0;
    if( $msg =~ s{\A!(pre|raw)!}{}mxs ) {
      $flag = $1 eq 'pre' ? 1 : $1 eq 'raw' ? 2 : 0;
    }
    push @{$messages}, Pagesmith::Message->new( $msg, 'warn', $flag );
  };
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
  my $IP = $r->headers_in->{ 'X-Forwarded-For' } || ($r->connection->can('remote_ip') ? $r->connection->remote_ip : $r->connection->client_ip );
  printf {*STDERR} "PID: %d/%d; Hostname: %s; Request: %s; IP: %s; Time: %s.\n",
    $PID, $r->subprocess_env->{'CHILD_COUNT'}, $r->hostname, $r->unparsed_uri, $IP, q().localtime;
  foreach ( @{$messages} ) {
    print {*STDERR} join "\n", $line, $_->render_txt($STACKTRACE_MAXDEPTH,$STACKTRACE_LEVEL),q();
  }
  print {*STDERR} "$bold\n\n";
  ## use critic;

  return DECLINED;
}

1;
