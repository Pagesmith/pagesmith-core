package Pagesmith::Utils::HTMLcritic;

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

use base qw(Pagesmith::Support);

use URI::Escape qw(uri_escape_utf8);
use HTML::Tidy;
use XML::Parser;
use English qw($EVAL_ERROR $INPUT_RECORD_SEPARATOR -no_match_vars);
use Pagesmith::Core qw(fullescape);

sub new {
  my( $class, $file, $access_level ) = @_;
  $access_level = 1 unless defined $access_level;
  my $self = {
    'filename'      => $file,
    'messages'      => [],
    'raw'           => [],
    'access_level'  => $access_level,
    'counts'        => {qw(Access 0 Error 0 Warning 0 Info 0)},
    'xml_error'     => undef,
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

sub n_info {
  my $self = shift;
  return $self->{'counts'}{'Info'};
}

sub n_access {
  my $self = shift;
  return $self->{'counts'}{'Access'};
}

sub level {
  my $self = shift;
  return $self->n_errors || defined $self->xml_error ? 'error'
       : $self->n_warnings                           ? 'warn'
       : $self->n_access || $self->n_info            ? 'msg'
       :                                               'info'
       ;
}

sub messages {
  my $self = shift;
  return @{ $self->{'messages'} };
}

sub raw {
  my $self = shift;
  return @{ $self->{'raw'} };
}

sub xml_error {
  my $self = shift;
  return $self->{'xml_error'};
}

sub invalid {
  my $self = shift;
  return defined $self->{'xml_error'} || @{$self->{'messages'}};
}

sub check {
  my $self = shift;
  return 'Unable to open file' unless open my $fh,'<',$self->{'filename'};
  my $contents;
  {
    local $INPUT_RECORD_SEPARATOR = undef;
    $contents = <$fh>;
  }
  close $fh; ## no critic (RequireChecked)
## Part 1 - run tidy..!

  ## First we will attempt to tidy!
  my %tmphash;
  my %order = qw(Error -10 Warning -5 Access -2 Info -1);
  ## no critic (BriefOpen)
  return 'Unable to execute tidy' unless( open my $scriptout, q(-|), sprintf 'tidy -eq -asxml -asxhtml -access %d %s 2>&1',
    $self->{'access_level'}, $self->{'filename'}
  );

  while(<$scriptout>) {
    chomp;
    if( m{\Aline\s+(\d+)\s+column\s+(\d+)\s+-\s+([[:upper:]][[:lower:]]+):\s+(.*)\Z}mxs ) { ## no critic (ComplexRegexes)
      push @{ $tmphash{ $3 }{ $1 }{ $2 } }, $4;
    }
    push @{ $self->{'raw'} }, $_;
  }
  close $scriptout; ## no critic (RequireChecked)
  ## use critic
  foreach my $level ( sort { ($order{$a}||0) <=> ($order{$b}||0) } keys %tmphash ) {
    foreach my $r   ( sort {            $a <=> $b         } keys %{ $tmphash{$level} } ) {
      foreach my $c ( sort {            $a <=> $b         } keys %{ $tmphash{$level}{$r} } ) {
        $self->push_message( { 'level' => $level, 'line' => $r, 'column' => $c, 'messages' => [ sort @{ $tmphash{$level}{$r}{$c} } ] } );
      }
    }
  }
  ## Now we will attempt to validate the XML...
  $contents =~ s{(<%.*?%>)}{(my $t=$1); $t=~ s{[^\n]}{ }g;$t}emxgs; ## Replace anything in <% %> with a space (except for "\n"... this preserves line/column numbers!
  my $parser = XML::Parser->new( 'ErrorContext' => 2 );
  my $val = eval { $parser->parse( $contents ); };
  if( $EVAL_ERROR ) {
    ( $self->{'xml_error'} = $EVAL_ERROR ) =~ s{at\s+/.*?\Z}{}mxgs;         # remove module line number
  }
  return;
}
sub push_message {
   my( $self, $hashref ) = @_;
   push @{$self->{'messages'}}, $hashref;
   $self->{'counts'}{$hashref->{'level'}}++;
   return $self;
}

## no critic (MagicNumbers)
my $access_levels = { ## Pulled from - http://www.aprompt.ca/Tidy/accessibilitychecks.html
  '1.1.1.1' => [ 'Error', 1 ],
  '1.1.1.2' => [ 'Warning', 1 ],
  '1.1.1.3' => [ 'Warning', 1 ],
  '1.1.1.4' => [ 'Warning', 1 ],
  '1.1.1.10' => [ 'Warning', 1 ],
  '1.1.1.11' => [ 'Warning', 1 ],
  '1.1.1.12' => [ 'Warning', 1 ],
  '1.1.2.1' => [ 'Warning', 1 ],
  '1.1.2.2' => [ 'Warning', 1 ],
  '1.1.2.3' => [ 'Warning', 1 ],
  '1.1.3.1' => [ 'Warning', 1 ],
  '1.1.4.1' => [ 'Error', 1 ],
  '1.1.5.1' => [ 'Error', 1 ],
  '1.1.6.1' => [ 'Error', 1 ],
  '1.1.6.2' => [ 'Error', 1 ],
  '1.1.6.3' => [ 'Error', 1 ],
  '1.1.6.4' => [ 'Error', 1 ],
  '1.1.6.5' => [ 'Error', 1 ],
  '1.1.6.6' => [ 'Error', 1 ],
  '1.1.8.1' => [ 'Warning', 1 ],
  '1.1.9.1' => [ 'Error', 1 ],
  '1.1.10.1' => [ 'Error', 1 ],
  '1.1.12.1' => [ 'Error', 1 ],
  '1.2.1.1' => [ 'Error', 1 ],
  '1.4.1.1' => [ 'Error', 1 ],
  '1.5.1.1' => [ 'Warning', 3 ],
  '2.1.1.1' => [ 'Warning', 1 ],
  '2.1.1.2' => [ 'Warning', 1 ],
  '2.1.1.3' => [ 'Warning', 1 ],
  '2.1.1.4' => [ 'Warning', 1 ],
  '2.1.1.5' => [ 'Warning', 1 ],
  '2.2.1.1' => [ 'Warning', 3 ],
  '2.2.1.2' => [ 'Warning', 3 ],
  '2.2.1.3' => [ 'Warning', 3 ],
  '2.2.1.4' => [ 'Warning', 3 ],
  '3.2.1.1' => [ 'Error', 2 ],
  '3.3.1.1' => [ 'Warning', 2 ],
  '3.5.1.1' => [ 'Error', 2 ],
  '3.5.2.1' => [ 'Warning', 2 ],
  '3.5.2.2' => [ 'Warning', 2 ],
  '3.5.2.3' => [ 'Warning', 2 ],
  '3.6.1.1' => [ 'Warning', 2 ],
  '3.6.1.2' => [ 'Warning', 2 ],
  '3.6.1.4' => [ 'Warning', 2 ],
  '4.1.1.1' => [ 'Error', 1 ],
  '4.3.1.1' => [ 'Error', 3 ],
  '4.3.1.2' => [ 'Error', 3 ],
  '5.1.2.1' => [ 'Error', 1 ],
  '5.1.2.2' => [ 'Error', 1 ],
  '5.1.2.3' => [ 'Error', 1 ],
  '5.2.1.1' => [ 'Warning', 1 ],
  '5.2.1.2' => [ 'Warning', 1 ],
  '5.3.1.1' => [ 'Warning', 2 ],
  '5.4.1.1' => [ 'Warning', 2 ],
  '5.5.1.1' => [ 'Error', 3 ],
  '5.5.1.2' => [ 'Error', 3 ],
  '5.5.1.3' => [ 'Error', 3 ],
  '5.5.1.6' => [ 'Error', 3 ],
  '5.5.2.1' => [ 'Error', 2 ],
  '5.6.1.1' => [ 'Warning', 3 ],
  '5.6.1.2' => [ 'Warning', 3 ],
  '5.6.1.3' => [ 'Warning', 3 ],
  '6.1.1.1' => [ 'Warning', 1 ],
  '6.1.1.2' => [ 'Warning', 1 ],
  '6.1.1.3' => [ 'Warning', 1 ],
  '6.2.1.1' => [ 'Error', 1 ],
  '6.2.2.1' => [ 'Warning', 1 ],
  '6.2.2.2' => [ 'Warning', 1 ],
  '6.2.2.3' => [ 'Warning', 1 ],
  '6.3.1.1' => [ 'Warning', 1 ],
  '6.3.1.2' => [ 'Warning', 1 ],
  '6.3.1.3' => [ 'Warning', 1 ],
  '6.3.1.4' => [ 'Warning', 1 ],
  '6.5.1.1' => [ 'Error', 2 ],
  '6.5.1.2' => [ 'Error', 2 ],
  '6.5.1.3' => [ 'Error', 2 ],
  '6.5.1.4' => [ 'Error', 2 ],
  '7.1.1.1' => [ 'Warning', 1 ],
  '7.1.1.2' => [ 'Warning', 1 ],
  '7.1.1.3' => [ 'Warning', 1 ],
  '7.1.1.4' => [ 'Warning', 1 ],
  '7.1.1.5' => [ 'Warning', 1 ],
  '7.2.1.1' => [ 'Warning', 2 ],
  '7.4.1.1' => [ 'Warning', 2 ],
  '7.5.1.1' => [ 'Warning', 2 ],
  '8.1.1.1' => [ 'Warning', 1 ],
  '8.1.1.2' => [ 'Warning', 1 ],
  '8.1.1.3' => [ 'Warning', 1 ],
  '8.1.1.4' => [ 'Warning', 1 ],
  '9.1.1.1' => [ 'Warning', 1 ],
  '9.3.1.1' => [ 'Error', 2 ],
  '9.3.1.2' => [ 'Error', 2 ],
  '9.3.1.3' => [ 'Error', 2 ],
  '9.3.1.4' => [ 'Error', 2 ],
  '9.3.1.5' => [ 'Error', 2 ],
  '9.3.1.6' => [ 'Error', 2 ],
  '10.1.1.1' => [ 'Warning', 2 ],
  '10.1.1.2' => [ 'Warning', 2 ],
  '10.2.1.1' => [ 'Error', 2 ],
  '10.2.1.2' => [ 'Error', 2 ],
  '10.4.1.1' => [ 'Error', 3 ],
  '10.4.1.2' => [ 'Error', 3 ],
  '10.4.1.3' => [ 'Error', 3 ],
  '11.2.1.1' => [ 'Warning', 2 ],
  '11.2.1.2' => [ 'Error', 2 ],
  '11.2.1.3' => [ 'Error', 2 ],
  '11.2.1.4' => [ 'Error', 2 ],
  '11.2.1.5' => [ 'Error', 2 ],
  '11.2.1.6' => [ 'Error', 2 ],
  '11.2.1.7' => [ 'Error', 2 ],
  '11.2.1.8' => [ 'Error', 2 ],
  '11.2.1.9' => [ 'Error', 2 ],
  '11.2.1.10' => [ 'Error', 2 ],
  '12.1.1.1' => [ 'Error', 1 ],
  '12.1.1.2' => [ 'Error', 1 ],
  '12.1.1.3' => [ 'Error', 1 ],
  '12.4.1.1' => [ 'Error', '2' ],
  '12.4.1.2' => [ 'Error', 2 ],
  '12.4.1.3' => [ 'Error', 2 ],
  '13.1.1.1' => [ 'Error', 2 ],
  '13.1.1.2' => [ 'Error', 2 ],
  '13.1.1.3' => [ 'Error', 2 ],
  '13.1.1.4' => [ 'Error', 2 ],
  '13.1.1.5' => [ 'Error', 2 ],
  '13.1.1.6' => [ 'Error', 2 ],
  '13.2.1.1' => [ 'Error', 2 ],
  '13.2.1.2' => [ 'Error', 2 ],
  '13.2.1.3' => [ 'Error', 2 ],
  '13.10.1.1' => [ 'Error', 3 ],
};
## use critic

sub access_level {
  my( $self, $key ) = @_;
  return $access_levels->{ $key }|| ['Unknown', 0];
}

1;
