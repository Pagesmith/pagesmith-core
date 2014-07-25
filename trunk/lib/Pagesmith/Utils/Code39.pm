package Pagesmith::Utils::Code39;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

## Action to handle delayed links (useful for testing purposes!)
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

my $c = 0;
const my @SYMBOLS    => (0..9,'A'..'Z',q(*));
const my %SYMBOL_MAP => map { $_=>$c++ } @SYMBOLS;
const my %SYMBOL_REV => reverse %SYMBOL_MAP;
const my $SYMBOL_MOD => scalar @SYMBOLS;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self;
}

sub checksum {
 my ($self, $str) = @_;
 return if $str =~ m{[^[:digit:][:upper:]*]}mxs;
 return $self->compute_checksum( $str );
}

sub is_invalid_modulo37_2 {
 my ($self, $str) = @_;
 return 'String too short' if length $str <= 1;
 return 'Invalid symbol'   if $str =~ m{[^[:digit:][:upper:]*]}mxs;
 return if $self->compute_checksum($str) eq q(*);
 return 'Invalid checksum';
}

sub compute_checksum {
 my ($self, $str) = @_;
 my $sum = 0;
 $sum = ($sum+$_) << 1 foreach map {$SYMBOL_MAP{$_}} split m{}mxs, $str;
 return $SYMBOL_REV{ (1-$sum) % $SYMBOL_MOD };
}

sub symbols {
  my $self = shift;
  return @SYMBOLS;
}

sub random_symbol {
  my $self = shift;
  return $SYMBOLS[ (rand @SYMBOLS) ];
}
1;
