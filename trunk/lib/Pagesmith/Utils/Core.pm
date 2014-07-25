package Pagesmith::Utils::Core;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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

## Support class for SVN submissions
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

const my $SPACER    => q(=) x 78;
const my $LINE      => q(-) x 78;
const my $ONEBYTE   => 8;
const my $MASK      => 127;
const my $CORE_DUMP => 128;

use Carp qw(croak);
use English qw(-no_match_vars $CHILD_ERROR $PROGRAM_NAME $ERRNO);

use Pagesmith::Core qw(user_info);

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub get_user_info {
  my( $self, $in_uid ) = @_;
  return user_info( $in_uid );
}

# Copied from contrib/hook-scripts/check-mime-type.pl, with some
# modifications. Moved the actual pipe creation to another subroutine
# (_pipe), so I can use _pipe in this code, and the part of the code
# that loops over the output of svnlook cat.

sub safe_read_from_pipe {
  my( $self, @command ) = @_;
  croak "$PROGRAM_NAME: safe_read_from_pipe passed no arguments.\n" unless @command;
  my $fh = $self->_pipe(@command);
  return q() unless $fh;
  my @output;
  while (<$fh>) {
    chomp;
    push @output, $_;
  }
  close $fh; ## no critic (RequireChecked)
  my $result = $CHILD_ERROR;
  my $exit   = $result >> $ONEBYTE;
  my $signal = $result & $MASK;                               ## no critic (BitwiseOperators)
  my $cd     = $result & $CORE_DUMP ? 'with core dump' : q(); ## no critic (BitwiseOperators)
  printf {*STDERR} "%s: pipe from '%s' failed %s: exit=%d signal=%s\n",
    $PROGRAM_NAME, "@command", $cd, $exit, $signal if $signal || $cd;
  return ($result, @output) if wantarray;
  return $result;
}

# Return the filehandle as a glob so we can loop over it elsewhere.
sub _pipe {
  my( $self, @command ) = @_;
  my $safe_read;
  my $pid = open $safe_read, q(-|); ## no critic (BriefOpen)
  die "$PROGRAM_NAME: cannot fork: $ERRNO\n" unless defined $pid;
  unless ($pid) {
    open STDERR, '>&STDOUT' or die "$PROGRAM_NAME: cannot dup STDOUT: $ERRNO\n";
    exec @command or die "$PROGRAM_NAME: cannot exec '@command': $ERRNO\n";
  }
  return $safe_read;
}

# Copied from contrib/hook-scripts/check-mime-type.pl
sub read_from_process {
  my( $self, @command ) = @_;
  croak "$PROGRAM_NAME: read_from_process passed no arguments.\n" unless @command;
  my ($status, @output) = $self->safe_read_from_pipe(@command);
  return @output unless $status;
  ## no critic (Carping)
  die "$PROGRAM_NAME: '@command' failed with no output.\n" unless @output;
  die sprintf "$PROGRAM_NAME: '@command' failed with this output:\n  %s\n", join "\n  ", @output;
  ## use critic
}

1;
