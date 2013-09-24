package Pagesmith::Cache::Base;

## Base class of Cache
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
const my $FUTURE => 0x7fffffff;
const my %UNIT_MULTIPLIER => (
  's'       =>          1,
  'sec'     =>          1,
  'second'  =>          1,
  'm'       =>         60,
  'min'     =>         60,
  'minute'  =>         60,
  'h'       =>      3_600,
  'hr'      =>      3_600,
  'hour'    =>      3_600,
  'd'       =>     86_400,
  'day'     =>     86_400,
  'w'       =>    604_800,
  'wk'      =>    604_800,
  'week'    =>    604_800,
  'mn'      =>  2_678_400,
  'month'   =>  2_678_400,
  'y'       => 31_622_400,
  'yr'      => 31_622_400,
  'year'    => 31_622_400,
);

use base qw(Exporter);

our @EXPORT_OK = qw(expires columns);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

my $columns = {
  'action'    => [qw(type cachekey)],
  'appdata'   => [qw(app cachekey)],
  'component' => [qw(type cachekey)],
  'config'    => [qw(location filename)],
  'feed'      => [qw(url)],
  'form'      => [qw(cachekey)],
  'form_file' => [qw(cachekey filekey file_ndx)],
  'page'      => [qw(type uri params)],
  'session'   => [qw(type session_key)],
  'template'  => [qw(type)],
  'tmpdata'   => [qw(type cachekey)],
  'tmpfile'   => [qw(type filename)],
  'variable'  => [qw(type cachekey)],
};

sub columns {
  my $key = shift;
  return @{ $columns->{$key} || [] };
}

sub expires {
  my $expires = shift;
  $expires ||= 0;
  if( $expires =~ m{\s}mxs ) {
    my ($count, $unit) = split m{\s+}mxs, $expires;
    $unit ||= 'day';
    $unit = lc $unit;
    $unit =~ s{s\Z}{}mxs;
    $expires = - $count * ( exists $UNIT_MULTIPLIER{ $unit } ? $UNIT_MULTIPLIER{ $unit } : 1 );
  }
  return
      $expires < 0 ? time - $expires
    : $expires > 0 ? $expires
    :                $FUTURE
    ;
}

1;
