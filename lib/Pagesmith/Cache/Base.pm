package Pagesmith::Cache::Base;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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
const my $COLUMNS => {
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

const my $TEXT_MODE => {
  'form'      => 1,
};


use base qw(Exporter);

our @EXPORT_OK = qw(expires columns text_mode);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

sub text_mode {
  my $key = shift;
  $key =~ s{[|].*}{}mxs;
  return exists $TEXT_MODE->{$key} ? $TEXT_MODE->{$key} : 0;
}

sub columns {
  my $key = shift;
  return return exists $COLUMNS->{$key} ? @{$COLUMNS->{$key}} : [];
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
