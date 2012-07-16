package Pagesmith::Cache::File;

## File system based cache
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
Readonly my $DIR_MASK => oct 775;

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);

use Pagesmith::Core qw(safe_md5);
use Pagesmith::Cache::Base qw(_expires);

my $fs_config = { 'path' => undef, 'options' => {} };

sub set_path {
  $fs_config->{'path'} ||= shift;
  return;
}

sub add_option {
  my ( $k, $v ) = @_;
  $fs_config->{$k} = $v;
  return;
}

sub configured {
  return $fs_config->{'path'} ? 1 : 0;
}

sub _get_path {

#@param $key,string Converts the key into a path....
  my $key = shift;
  my @path = split m{\|}mxs, $key;
  return unless @path;
  foreach (@path) {
    return if m{\A/}mxs || m{/\Z}mxs || m{//+}mxs || m{[^-\w\./]}mxs;
    ## musn't start with a q(/), have multiple '/' OR contain letters outside '.-\w/'
  }
  my $last_part = pop @path;
  my $hash      = safe_md5($last_part);
## To make sure the last directory doesn't get too big hash into sub-parts
  push @path, substr( $hash, 0, 1 ), substr( $hash, 1, 1 ), $last_part;

  @path = map { split m{/}mxs, $_ } @path;
  foreach (@path) {
    return if m{\A\.\.?\Z}mxs;    # return if there are any "." or ".." in the path
  }
  return @path;
}

##no critic (BuiltinHomonyms)
sub exists {

#@param $key,string Key in cache
#@return boolean True if key is in cache.

## IF the entry has expired then the cache entry is removed from
## the disk.. Make sure that fs_config->{'path'} is SAFE!!!!

  my $key  = shift;
  my @path = _get_path($key);
  return unless $fs_config->{'path'};
  return unless @path;                  ## Invalid path!
  my $fn = $fs_config->{'path'} . join q(/), @path;    ## This is safe!!
  return unless -e $fn && -r $fn;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$expires,$ctime,$blksize,$blocks) = stat _;
  if ( $expires < time ) {
    ## It exists but has expired so remove it and return!
    unlink $fn;
    return;
  }
  ## Slurp the file and return the contents along with the expiry time!
  return 1;
}
##use critic (BuiltinHomonyms)

sub get {

#@param string Key in cache
#@return string,timestamp the value from the cache, and the expiry date

## Returns value of undef if not found! IF the entry has expired
## then the cache entry is removed from the disk.. Make sure that
## fs_config->{'path'} is SAFE!!!!

  my $key  = shift;
  my @path = _get_path($key);
  return unless @path;    ## Invalid path!
  my $fn = $fs_config->{'path'} . join q(/), @path;    ## This is safe!!
  return unless -e $fn && -r $fn;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$expires,$ctime,$blksize,$blocks) = stat _;
  if ( $expires < time ) {
    ## It exists but has expired so remove it and return!
    unlink $fn;
    return;
  }
  ## Slurp the file and return the contents along with the expiry time!
  return unless open my $fh, '<', $fn;
  local $INPUT_RECORD_SEPARATOR = undef;
  my $content = <$fh>;
  close $fh; ##no critic (CheckedSyscalls CheckedClose)
  return ( $content, $expires );
}

sub unset {

#@param string Key in cache

## Remove the entry from the cache

  my $key  = shift;
  my @path = _get_path($key);
  return unless @path;    ## Invalid path!
  my $fn = $fs_config->{'path'} . join q(/), @path;    ## This is safe!!
  return unless -e $fn && -r $fn;
  return unlink $fn;
}

sub touch {

#@param string Key in cache
#@param timestamp? Expiry date (-ve nos - seconds till expiry, +ve nos unix time stamps

## Change the expiry time of the entry in the cache
  my ( $key, $expires ) = @_;
  my @path = _get_path($key);
  return unless @path;    # Invalid path!
  my $fn = $fs_config->{'path'} . join q(/), @path;    # This is safe!!
  return unless -e $fn && -r $fn;
  utime undef, _expires($expires), $fn;
  return 1;
}

##no critic (AmbiguousNames);
sub set {

#@param string Key in cache
#@param string "serialised" content to be cached
#@param timestamp? Expiry date (-ve nos - seconds till expiry, +ve nos unix time stamps
#@return boolean true if cache entry created

## Store the entry in the filesystem based hash
## The file mtime is set to the expiry date of the cache entry!

  my ( $key, $content, $expires ) = @_;
  my @path = _get_path($key);
  return unless @path;    ## Invalid path! return....
  my $file       = pop @path;
  my $final_path = $fs_config->{'path'};    # Start with the base path...
  foreach (@path) {                         # Create the directories if they don't exist...
    $final_path .= "$_/";
    mkdir $final_path, $DIR_MASK unless -e $final_path;
  }
  my $fn = $final_path . $file;
  return unless open my $fh, '>', $fn;          # Create the file and write to it!
  return unless print {$fh} $content; # The parent cache module has already 'serialised' the object
  close $fh; ##no critic (CheckedSyscalls CheckedClose)
  utime undef, _expires($expires), $fn;     # Change the expiry date timestamp...
  return 1;
}
##use critic (AmbiguousNames);

1;
