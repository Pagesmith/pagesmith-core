package Pagesmith::Utils::Code39;

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
