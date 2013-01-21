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

use Readonly qw(Readonly);
Readonly my $FUTURE => 0x7fffffff;

use base qw(Exporter);

our @EXPORT_OK = qw(expires columns);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

my $columns = {
  'tmpfile'   => [qw(type filename)],
  'action'    => [qw(type cachekey)],
  'component' => [qw(type cachekey)],
  'variable'  => [qw(type cachekey)],
  'feed'      => [qw(url)],
  'config'    => [qw(location filename)],
  'tmpdata'   => [qw(type cachekey)],
  'form'      => [qw(cachekey)],
  'form_file' => [qw(cachekey filekey file_ndx)],
  'template'  => [qw(type)],
  'page'      => [qw(type uri params)],
  'appdata'   => [qw(app cachekey)],
  'session'   => [qw(type session_key)],
};

sub columns {
  my $key = shift;
  return @{ $columns->{$key} || [] };
}

sub expires {
  my $expires = shift;

  $expires ||= 0;
  return
      $expires < 0 ? time - $expires
    : $expires > 0 ? $expires
    :                $FUTURE
    ;
}

1;
