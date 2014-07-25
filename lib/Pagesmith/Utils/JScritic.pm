package Pagesmith::Utils::JScritic;

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
use Pagesmith::ConfigHash qw(get_config);

use Const::Fast qw(const);
const my %IGNORE_WARNING => map { ($_=>1) } qw(Z999);

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

  my $res = $self->run_cmd( [qw(jshint --verbose --config),
                            get_config('UtilsDir').'/config/jshint.json',
                            $self->{'filename'}] );
  ## no critic (ComplexRegexes)
  my @error_messages = map { m{\A(\S+):[ ]line[ ](\d+),[ ]col[ ](\d+),[ ](.*?[ ][(](([EW])\d{3})[)])\Z}mxs ?
                           {( 'source'   => $1,
                             'line'     => $2,
                             'col'      => $3,
                             'messages' => [ $4 ],
                             'code'     => "$5",
                             'level'    => $6 eq 'E' ? 'Error' : exists $IGNORE_WARNING{$5} ? 'Ignored' : 'Warning',
                           )} : () }
                           @{$res->{'stdout'}};
  ## use critic
  my $errors  = grep { $_->{'level'} eq 'Error' }   @error_messages;
  my $ignored = grep { $_->{'level'} eq 'Ignored' } @error_messages;
  my $warns   = @error_messages - $errors - $ignored;
  $self->{'messages'} = \@error_messages;
  $self->{'counts'}   = { 'Error' => $errors, 'Warning' => $warns, 'Ignored' => $ignored };
  return;
}

1;
