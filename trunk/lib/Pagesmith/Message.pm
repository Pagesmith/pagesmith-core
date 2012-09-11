package Pagesmith::Message;

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

use HTML::Entities qw(encode_entities);

my %levels = qw(
  fatal 400
  error 300
  warn  200
  info  100
  all     0
);

my %php_error_levels = qw(
  1     fatal
  2     warn
  4     error
  8     warn
  16    fatal
  32    warn
  64    fatal
  128   warn
  256   fatal
  512   warn
  1024  warn
  2048  warn
  4096  error
  8192  warn
  16384 warn
);
my %php_error_names = qw(
  1     ERROR
  2     WARNING
  4     PARSE
  8     NOTICE
  16    CORE_ERROR
  32    CORE_WARNING
  64    COMPILE_ERROR
  128   COMPILE_WARNING
  256   USER_ERROR
  512   USER_WARNING
  1024  USER_NOTICE
  2048  STRICT
  4096  RECOVERABLE_ERROR
  8192  DEPRECATED
  16384 USER_DEPRECATED
);
sub from_php {
  my( $class, $error ) = @_;
  my $severity = $php_error_levels{ $error->{'error_no'} } || 'warn';
  my $caller_info = [
    { 'package'  => q(-),
      'filename' => $error->{'error_file'},
      'line'     => $error->{'error_line'},
      'sub'      => q(-),
    },
  ];
  foreach my $row ( @{ $error->{'stacktrace'} } ) {
    push @{$caller_info}, {
      'package'  => $row->{'class'} ||q(-),
      'filename' => $row->{'file'}  ||q(-),
      'line'     => $row->{'line'}  ||q(-),
      'sub'      => ($row->{'type'} ||q()).($row->{'function'} ||q(-)),
    };
  }
  my $type = $php_error_names{ $error->{'error_no'} } || "UNKNOWN: $error->{'error_no'}";
  my $self = {
    '_severity' => $severity,
    '_message'  => "$error->{'error_str'} (PHP $type)",
    '_pre'      => 0,
    '_caller'   => $caller_info,
  };
  bless $self, $class;
  return $self;
}
sub new {
## Create a new message object
  my( $class, $message, $severity, $pre ) = @_;
  $severity = 'error'           unless defined $severity && exists $levels{$severity};
  $message  = q(- no message -) unless defined $message;
  $pre      = 0                 unless defined $pre && ($pre == 1 || $pre == 2);

  my @caller_info;
  my $c           = 1;
  while ( my ( $package, $filename, $line, $sub, $hasargs, $wantarray, $eval, $require ) = caller $c++ ) {
    $package = "MPR::$1" if $package =~ m{\AModPerl::ROOT::ModPerl::Registry::(.*)}mxs;
    $sub     = "MPR::$1" if $sub     =~ m{\AModPerl::ROOT::ModPerl::Registry::(.*)}mxs;
    $sub     = 'warn'    if $sub     eq 'Pagesmith::Apache::Errors::__ANON__';
    push @caller_info, {
      'package'   => $package,
      'filename'  => $filename,
      'line'      => $line,
      'sub'       => $sub,
      'hasargs'   => $hasargs,
      'wantarray' => $wantarray,
      'eval'      => $eval,
      'require'   => $require,
    };
  }
  my $self = {
    '_severity' => $severity,
    '_message'  => $message,
    '_pre'      => $pre,
    '_caller'   => \@caller_info,
  };
  bless $self, $class;
  return $self;
}

sub new_from_hash {
  my( $class, $hash, $prefix ) = @_;
  bless $hash,  $class;
  return $hash;
}

sub severity_less_than {
  my $self     = shift;
  my $severity = shift;

  ## Incase severity_less_than is called with the wrong value

  return 1 unless exists $levels{$severity};
  return $levels{ $self->{'_severity'} } < $levels{$severity};
}

sub render {
  my( $self, $include_stacktrace, $stacktrace_level ) = @_;
  $stacktrace_level = 'warn' unless defined $stacktrace_level && exists $levels{$stacktrace_level};

  my $msg = $self->{'_pre'} == 2 ? $self->{'_message'} : encode_entities( $self->{'_message'} );
  $msg =~ s{\s+\Z}{}mxgs;
  $msg =~ s{\n}{<br />}mxgs;
  my $html = sprintf qq(\n<tr class="message_%s">\n  <th class="message_first">[%s]</th>\n  <th colspan="4" class="%s">%s</th>\n</tr>\n),
    $self->{'_severity'}, $self->{'_severity'}, $self->{'_pre'} == 1 ? 'message_pre' : 'message_normal', $msg;

  return $html unless $include_stacktrace; ## Don't include stack trace-at all!
  return $html if $self->severity_less_than($stacktrace_level); ## Don't stack trace "info" messages

  foreach ( @{ $self->{'_caller'} } ) {
    ##no critic (ImplicitNewlines)
    $html .= sprintf '
<tr class="message_%s">
  <td class="message_first">&nbsp;</td>
  <td class="message_package">%s</td>
  <td class="message_sub">%s</td>
  <td class="message_number">%d</td>
  <td class="message_file">%s</td>
</tr>',
      $self->{'_severity'},
      encode_entities( $_->{'package'} ),
      encode_entities( $_->{'sub'} ),
      encode_entities( $_->{'line'} ),
      encode_entities( $_->{'filename'} );
    ##use critic (ImplicitNewlines)
    last unless --$include_stacktrace;
  }

  return $html;
}

sub render_txt {
  my( $self, $include_stacktrace, $stacktrace_level ) = @_;
  $stacktrace_level = 'warn' unless defined $stacktrace_level && exists $levels{$stacktrace_level};

  my @out = map { sprintf '[%8s] %s', $self->{'_severity'}, $_ } split m{\n}mxs, $self->{'_message'};

  return @out unless $include_stacktrace; ## Don't include stack trace-at all!
  return @out if $self->severity_less_than($stacktrace_level); ## Don't stack trace "info" messages

  foreach ( @{ $self->{'_caller'} } ) {
    push @out, sprintf ' %8s: %5d %-40s %-40s %s',
      $self->{'_severity'},
      $_->{'line'},
      $_->{'package'},
      $_->{'sub'},
      $_->{'filename'};
    last unless --$include_stacktrace;
  }

  return @out;
}

1;
