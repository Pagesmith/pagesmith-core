package Pagesmith::Utils::JScritic;

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

use URI::Escape qw(uri_escape_utf8);
use HTML::Tidy;
use XML::Parser;
use English qw($EVAL_ERROR $INPUT_RECORD_SEPARATOR -no_match_vars);
use Pagesmith::Core qw(fullescape);

use Readonly qw(Readonly);
Readonly my $JSL_COMMAND       => '/www/utilities/jsl -conf /www/utilities/jsl.conf -process';
Readonly my $ERROR_BLOCK_LINES => 4;
Readonly my $ERROR_BLOCK_PARTS => 4;

use base qw(Pagesmith::Support);

sub new {
  my( $class, $file ) = @_;
  my $self = {
    'filename'      => $file,
    'messages'      => [],
    'counts'        => {qw(Error 0 Warning 0 Ignored 0)},
  };
  bless $self, $class;
  return $self;
}

sub n_errors {
  my $self = shift;
  return $self->{'counts'}{'Error'};
}

sub n_warnings {
  my $self = shift;
  return $self->{'counts'}{'Warning'};
}

sub n_ignored {
  my $self = shift;
  return $self->{'counts'}{'Ignored'};
}

sub messages {
  my $self = shift;
  return @{ $self->{'messages'} };
}

sub push_message {
   my( $self, $hashref ) = @_;
   push @{$self->{'messages'}}, $hashref;
   return $self;
}

sub xml_error { # for compatability with HTMLcritic
  return 0;
}

sub check {
  my $self = shift;
  return 'Unable to open file' unless -e $self->{'filename'} && -f _ && -r _; ## no critic (Filetest_f) # Does have to be a physical file!

  my @lines;
  if( open my $fh, q(-|), split( m{\s+}mxs, $JSL_COMMAND ), $self->{'filename'} ) {
    @lines = <$fh>;
    close $fh; ## no critic (RequireChecked)
  } else {
    return 'Unable to process file';
  }

  splice @lines,0,$ERROR_BLOCK_LINES;
  my $counts_line = pop @lines;
  my( $errors,$warns ) = $counts_line =~ m{\A(\d+)\serror[(]s[)],\s(\d+)\swarning[(]s[)]}mxs ? ($1,$2) : (0,0);
  my $ignored = 0;
  my @error_messages;
  while(@lines>0) {
    my ($msg,$source,$arrow,$blank) = splice @lines,0,$ERROR_BLOCK_LINES;
    my $c = 0;
    if( defined $arrow && $arrow =~ m{\A([.]*)\^}mxs ) {
      $c = length $1;
    } else {
      splice @lines,0,0,defined $source ? $source : (),defined $arrow ? $arrow:(),defined $blank ? $blank:();
      $source = q();
      $arrow  = q();
      $blank  = q();
    }
    next unless defined $blank;
    chomp $msg;
    my($file,$r,$type,$message) = split m{:}mxs, $msg, $ERROR_BLOCK_PARTS;
    next unless defined $type;

    my $level = $type =~ m{Error}mxis ? 'Error' : 'Warning';
    $message =~ s{\A\s+}{}mxs;
    $message =~ s{\s+\Z}{}mxs;
    chomp $source;
# Ignore
#  (1) console errors - but good to display them as they are diagnostic
#  (2) unexpected end of line - if using <-'. to split chained jQuery blocks
    if( $message eq 'undeclared identifier: console' ||
        $message eq 'unexpected end of line; it is ambiguous whether these lines are part of the same statement' &&
        $source =~ m{\A\s*[.]}mxs ) {
      $warns  --;
      $ignored++;
      $level  = 'Ignored';
    }

    $type =~ s{\A\s+}{}mxs;
    $type =~ s{\s+\Z}{}mxs;
    push @error_messages, {
      'level'    => $level,
      'messages' => [ $message ],
      'line'     => $r,
      'column'   => $c,
    };
  }
  $self->{'messages'} = \@error_messages;
  $self->{'counts'}   = { 'Error' => $errors, 'Warning' => $warns, 'Ignored' => $ignored };
  return;
}

1;
