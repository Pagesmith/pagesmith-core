package Pagesmith::Utils::Documentor::File;

##g
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

use base qw(Pagesmith::Utils::Documentor);

sub new {
#@params (class) (string method name)
#@return (self)
## Generate file object...
  my( $class, $name ) = @_;
  my $self = {
    'name'        => $name,
    'line_no'     => 0,
    'raw_lines'   => [],
    'lines'       => [],
    'fh'          => undef,
  };
  bless $self, $class;
  return $self;
}

sub name {
#@params (self)
#@return (string) name
## Returns name of package;
  my $self = shift;
  return $self->{'name'};
}

sub open_file {
  my $self = shift;
  unless( $self->{'fh'} ) {
    open $self->{'fh'}, q(<), $self->{'name'}; ## no critic (RequireChecked)
  }
  return $self;
}

sub close_file {
  my $self = shift;
  close $self->{'fh'} if $self->{'fh'}; ## no critic (RequireChecked)
  $self->{'fh'} = undef;
  return $self;
}

sub next_line {
  my $self = shift;
  my $fh = $self->{'fh'};
  my $line = <$fh>;
  return unless defined $line;
  $self->push_line( $line );
  return $line;
}

sub push_line {
#@params (self)
#@return (self)
## push a line of code onto the lines arrays...
  my ( $self, $line ) = @_;
  $self->{'line_no'}++;
  chomp $line;
  $line =~ s{\s+\Z}{}mxs;
  my $formatted_line = sprintf "%6d: %s\n", $self->{'line_no'}, $line;
  push @{$self->{'raw_lines'}}, $formatted_line;
  push @{$self->{'lines'}},     $formatted_line;
  return $self;
}

sub empty_line {
#@params (self)
#@return (self)
## empty this line to hide documentation
  my $self = shift;
  $self->{'lines'}[-1] = q();
  return $self;
}

sub line_count {
#@param (self)
#@return (int) no of lines in file
  my $self = shift;
  return $self->{'line_no'};
}

sub line_slice {
#@params (self) (int start) (int end)?
#@return (string[]) arrayref containing chunk of source code
## Documentation text is removed!
  my( $self, $start, $end ) = @_;
  return [@{$self->{'lines'}}[ ($start-1)..($end-1) ]];
}

1;
