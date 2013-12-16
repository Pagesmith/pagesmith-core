package Pagesmith::Component::Developer::Messages;

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

use base qw(Pagesmith::Component);

use HTML::Entities qw(encode_entities);
use English qw(-no_match_vars $PID);
use Socket qw(inet_aton AF_INET);

use Pagesmith::Message;

sub usage {
  return {
    'parameters'  => q(),
    'description' => q(Render error messages in a neat format to help debugging),
    'notes' => [],
  };
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'severity',          'defn' => '=s', 'default' => 'fatal' },
    { 'code' => 'stack_trace',       'defn' => '=i', 'default' => 0       },
    { 'code' => 'stack_trace_level', 'defn' => '=s', 'default' => 'fatal' },
  );
}

sub _resolve {
  my $ip = shift;
  my $iaddr = inet_aton($ip); # or whatever address
  my $name  = gethostbyaddr($iaddr, AF_INET) || 'unknown';
  return "$name ($ip)";
}

sub execute {
  my $self = shift;
  return q() if $self->is_xhr;
## Get the "pnote attached" messages && flush them...
  my $html = q();

  my $messages = $self->r->pnotes( 'errors' )||[];

  my $phpe = $self->r->notes->get('errors');

  if( $phpe ) {
    push @{$messages}, map { Pagesmith::Message->from_php( $_ ) } @{ $self->json_decode($phpe) ||[] };
    $self->r->notes->unset('errors');
  }

## Handling a local redirect (this picks up errors sent by the previous error handler)
  if( $self->r->prev ) {
    my $t = $self->r->prev->pnotes( 'errors' )||[];
    push @{$messages},@{$t};
    ## Remove errors from previous request!
    $self->r->prev->pnotes( 'errors', [] );
  }
  my $severity = $self->option( 'severity' ) || 'fatal';
  my $stack_trace       = $self->option( 'stack_trace' ) || 0;
  my $stack_trace_level = $self->option( 'stack_trace_level' ) || 'fatal';

  return q() unless @{$messages};

  my @remaining;
  my $count = 0;
  foreach my $message ( @{$messages} ) {
    if( $message->severity_less_than( $severity ) ) {
      push @remaining, $message;
    } else {
      $count++;
      $html .= $message->render( $stack_trace, $stack_trace_level );
    }
  }
  splice @{$messages},0,@{$messages},@remaining;

  return q() unless $html;

  my $IP = $self->r->headers_in->{ 'X-Forwarded-For' } || $self->remote_ip;

  $IP =~ s{(\b\d+[.]\d+[.]\d+[.]\d+)}{_resolve($1)}mxges;
  ## no critic (ImplicitNewlines)
  return sprintf q(
<div style="clear:both;overflow:auto" class="panel box-warn collapsible collapsed developer devpanel">
  <h3>Warning and error messages: Count: %d; PID: %d</h3>
  <dl class="twocol">
    <dt>Request:</dt><dd>%s</dd>
    <dt>IP:</dt><dd>%s</dd>
  </dl>
  <table summary="Table of error, warning and information errors for the page" class="messages">
    <tbody>%s</tbody>
  </table>
</div>),
    $count, $PID,
    encode_entities( $self->r->unparsed_uri ),
    $IP,
    $html;
  ## use critic
}

1;

__END__

h3. Syntax

<% Developer_Messages
  -severity=(fatal|error|warn|info|all)
  -stack_trace=
  -stack_trace_level=
%>

h3. Purpose

To take both Perl and PHP errors and display them in the browser so that
log files don't have to be investigated.

h3. Options

* severity (optional default 'fatal') - lowest level of errors to display to browser

* stack_trace (optional default 0) - number of lines of stack trace to show - or NONE if stack_trace=0

* stack_trace_level (optional default 'fatal') - lowest level of errors to display stack-trace for

h3. Notes

* Obviously only catches errors on requests that render HTML all other errors are
  grouped and formatted in the error logs.

* Any errors not displayed will appear in error logs

* Only runs on dev servers

h3. See also

* Module: Pagesmith::Message

* Module: Pagesmith::Apache::Errors

h3. Examples

* <% Developer_Messages -severity=all -stack_trace=5 -stack_trace_level=warn ~%>

h3. Developer notes

