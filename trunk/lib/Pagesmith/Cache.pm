package Pagesmith::Cache;

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

## Caches generated content to a memcached, SQL and/or file system backed cache
## To improve the performance of the website.
## Currently we have caches tuned to the followins sorts of data:
#* page - templated webpage content
#* template - compiled webpage template
#* component - the output for the output of a directive
#* tmpfile - storage of a file which is accessible through the webserver URL - handled by Pagesmith::Apache::TmpFile
#* tmpdata - storage of arbitrary data structures

use Data::Dumper;

use Pagesmith::Cache::Memcache;
use Pagesmith::Cache::SQL;
use Pagesmith::Cache::File;
use Pagesmith::ConfigHash qw(site_key get_config);

use Data::UUID;
use Const::Fast qw(const);
const my $UUID64_LENGTH         => 22;
const my $MICRO_SLEEP           =>  0.001;
const my $MAX_SLEEP             =>  5;

#= Usage

##no critic (CommentedOutCode)
##   my $ch = Pagesmith::Cache->new( 'tmpfile', 'sjadlkaruoire14.js' );
##   my $content = $ch->get();
##   if( $content ) {
##     $ch->touch( -24 * 60 * 60 );         # Force to stay alive for 24 hrs
##   } else {
##     $content = _generate_content();      # Generate content
##     $ch->set( $content, -24 * 60 * 60 ); # Cache for 1 day
##   }
##use critic (CommentedOutCode)

#= Constructor

sub new {

#@param string   type of entry to Cache
#@param string   key of entry to Cache
#@param string?  cache types to use
#@return self

## Constructor takes two parameters - type of entry and key of entry.
## A third optional parameter indicates the type of cache to use and
## consists of a string of letters M, S, F which indicate whether we
## are using memcached, sql or file cache caches..

## There may be reasons to bypass or include some of these cache types for a
## particular query - either it is VERY SLOW and so we can use our "slowest"
## cache methods - or it is relatively fast and all we want to use is our
## fastest caches... and we aren't worried about losing the cached content!

## note the default setting is defined in the VirtualHost configuration
## and I would suggest that MS is used i.e. memcached for speed and
## SQL for persistance! Some areas of the site will fail if entries go
## out of the memcached memory - hence the need for a more permanent
## disk based solution... this is definitely true if temporary files are
## pushed out of the cache but the HTML that refers to them is not ...
## e.g. the merged and minified JS/CSS files and the thumbnails image
## produced by Image directive.

#@elem _mem boolean true if Memcache cache is enabled AND configured
#@elem _sql boolean true if SQL cache is enabled AND configured
#@elem _fs boolean true if file cache is enabled AND configured
#@elem _type string type of cache entry
#@elem _key string key in hash
#@elem _cachekey string concatenated hash key

 ##no critic (CallsToUnexportedSubs)
  my($class, $type, $key, $cachetype, $site_key ) = @_;
  $cachetype ||= get_config('CacheType') || 'MS';
  $site_key ||= site_key;
  $key =~ s{[^-\w.=|]}{}mxgs;
  my $self = {
    '_mem' => ( $cachetype =~ m{M}mxs && Pagesmith::Cache::Memcache::configured() ? 1 : 0 ),
    '_sql' => ( $cachetype =~ m{S}mxs && Pagesmith::Cache::SQL::configured()      ? 1 : 0 ),
    '_fs'  => ( $cachetype =~ m{F}mxs && Pagesmith::Cache::File::configured()     ? 1 : 0 ),
    '_type'     => $type,
    '_key'      => $key,
    '_cachekey' => join q(|), $type, $site_key, $key,
  };
  bless $self, $class;
  return $self;
 ##use critic (CallsToUnexportedSubs)
}

#= Public functions

## The following functions allow the user to access the web cache

##no critic (AmbiguousNames)
sub set {

#@param self
#@param string Content to store
#@param expires? Expiry time:
#*  if set and > 0 specifies expiry absoulte expiry time e.g. 1293840000 sets expiry time to midnight 31/12/2009
#*  if less than 0 it specifies the number of seconds into the future to expire e.g. -60 expire in one minute
#@return void

## Store the contents of content_ref to memcached (optional)

  my ( $self, $content, $expires ) = @_;

  # Freeze the content either as "0$string" or "1{serialized ref}"
  $content = $self->_freeze($content);

  # Write to the various caches
 ##no critic (CallsToUnexportedSubs)
  Pagesmith::Cache::Memcache::set( $self->{'_cachekey'}, $content, $expires ) if $self->{'_mem'};
  Pagesmith::Cache::SQL::set( $self->{'_cachekey'}, $content, $expires ) if $self->{'_sql'};
  Pagesmith::Cache::File::set( $self->{'_cachekey'}, $content, $expires ) if $self->{'_fs'};
 ##use critic (CallsToUnexportedSubs)
  return;
}
##use critic (AmbiguousNames)

sub touch {

#@param self
#@param expires? Expiry time (see ->set)
#@return void

## Store the contents of content_ref to memcached (optional)

  my ( $self, $expires ) = @_;
 ##no critic (CallsToUnexportedSubs)
  Pagesmith::Cache::Memcache::touch( $self->{'_cachekey'}, $expires ) if $self->{'_mem'};
  Pagesmith::Cache::SQL::touch( $self->{'_cachekey'}, $expires ) if $self->{'_sql'};
  Pagesmith::Cache::File::touch( $self->{'_cachekey'}, $expires ) if $self->{'_fs'};
 ##use critic (CallsToUnexportedSubs)
  return;
}

sub unset {

#@param self
#@return void

## Remove the element form all the caches

  my ($self) = @_;
 ##no critic (CallsToUnexportedSubs)
  Pagesmith::Cache::Memcache::unset( $self->{'_cachekey'} ) if $self->{'_mem'};
  Pagesmith::Cache::SQL::unset( $self->{'_cachekey'} )      if $self->{'_sql'};
  Pagesmith::Cache::File::unset( $self->{'_cachekey'} )     if $self->{'_fs'};
 ##use critic (CallsToUnexportedSubs)
  return;
}

##no critic (BuiltinHomonyms)
sub exists {

#@param self
#@return boolean Existance in cache

## Returns true if the cache element exists in one of the enabled caches

  my $self = shift;
 ##no critic (CallsToUnexportedSubs)
  return
       $self->{'_mem'} && Pagesmith::Cache::Memcache::exists( $self->{'_cachekey'} )
    || $self->{'_sql'} && Pagesmith::Cache::SQL::exists( $self->{'_cachekey'} )
    || $self->{'_fs'}  && Pagesmith::Cache::File::exists( $self->{'_cachekey'} )
    || 0;
 ##use critic (CallsToUnexportedSubs)
}
##use critic (BuiltinHomonyms)

sub get {

#@param self
#@return undef/string/hash Object stored in cache if present

## Retrieve the entry from memcached,SQL or disk cache if it is there.
## Side effect if the entry is in a slow cache and a faster cache is enabled
## then the contents are copied to the faster cache - typicall this will
## allow re-population from the SQL cache to the memcached cache

  my $self = shift;
  my ( $content, $expires );
 ##no critic (CallsToUnexportedSubs)
  if ( $self->{'_mem'} ) {    # We have memcache set up and enabled
    ($content) = Pagesmith::Cache::Memcache::get( $self->{'_cachekey'} );
    return $self->_thaw($content) if defined $content;    # The file is served from memcache!
  }
  if ( $self->{'_sql'} ) {                                # We have SQL set up and enabled...
    ( $content, $expires ) = Pagesmith::Cache::SQL::get( $self->{'_cachekey'} );
    if ( defined $content ) {

      # If memcached is enabled copy it back so that next time we get the
      # entries out of memcached!
      Pagesmith::Cache::Memcache::set( $self->{'_cachekey'}, $content, $expires ) if $self->{'_mem'};
      return $self->_thaw($content);
    }
  }
  return unless $self->{'_fs'};

  # Finally work with the file cache if set up and enabled!
  ( $content, $expires ) = Pagesmith::Cache::File::get( $self->{'_cachekey'} );
  return unless defined $content;

  # If we have either the SQL cache or Memcache cache or both enabled we can write the
  # entry back into these for faster retrieval later...
  Pagesmith::Cache::SQL::set( $self->{'_cachekey'}, $content, $expires ) if $self->{'_sql'};
  Pagesmith::Cache::Memcache::set( $self->{'_cachekey'}, $content, $expires ) if $self->{'_mem'};
 ##use critic (CallsToUnexportedSubs)
  return $self->_thaw($content);
}

#= Helper functions

#== Checking existance of caches

sub mem_configured {
#@param self
#@return boolean true if memcached cache configured and enabled
  my $self = shift;
  return $self->{'_mem'} && Pagesmith::Cache::Memcache::configured; ##no critic (CallsToUnexportedSubs)
}

sub sql_configured {

#@param self
#@return boolean true if SQL cache configured and enabled
  my $self = shift;
  return $self->{'_sql'} && Pagesmith::Cache::SQL::configured; ##no critic (CallsToUnexportedSubs)
}

sub fs_configured {

#@param self
#@return boolean true if File cache configured and enabled
  my $self = shift;
  return $self->{'_fs'} && Pagesmith::Cache::File::configured; ##no critic (CallsToUnexportedSubs)
}

#== Freezeing and thawing objects

sub _freeze {

#@param self
#@param string/ref Content to be frozen
#@return string Frozen object

## Freezes an object and returns the frozen string - the first character of the
## returned string is either 1 frozen or 0 raw.

  my ( $self, $content ) = @_;
  return ref($content)
    ? '1' . Data::Dumper->new( [$content], ['content'] )->Terse(1)->Indent(0)->Dump()
    : '0' . $content;
}

sub _thaw {

#@param self
#@param string Frozen content
#@return string/ref Unfrozen object

## Unfreezes an object and returns the object or string - the first character of
## the frozen string is 1 the object is a frozen reference, if 0 it is a raw
## string
  my ( $self, $content ) = @_;
  my $t = substr( $content, 0, 1, q() ) ? eval $content : $content; ##no critic (StringyEval)
  return $t;
}

sub lock_details {
  my $self = shift;
  unless( exists $self->{'_lock_key'} ) {
    $self->{'_lock_key'} = 'lock:'.$self->{'_cachekey'};
    $self->{'uuid_gen'} ||= Data::UUID->new;
    ( my $t = $self->{'uuid_gen'}->create_b64() ) =~ s{[+]}{-}mxgs;
    $t =~ s{/}{_}mxgs;
    $self->{'_lock_val'} = substr $t, 0, $UUID64_LENGTH;    ## Don't really need the two == signs at the end!
  }
  return ($self->{'_lock_key'},$self->{'_lock_val'});
}

sub lock_val {
  my $self = shift;
  return $self->{'_lock_val'};
}

##no critic (CallsToUnexportedSubs)
sub get_lock {
  my( $self, $expiry, $timeout ) = @_;
  return $self->{'_mem'} ? Pagesmith::Cache::Memcache::get_lock( $self->lock_details, $expiry, $timeout )
       : $self->{'_sql'} ? Pagesmith::Cache::SQL::get_lock(       $self->lock_details, $expiry, $timeout )
       : 1
       ;
}

sub release_lock {
  my $self = shift;
  return $self->{'_mem'} ? Pagesmith::Cache::Memcache::release_lock( $self->lock_details )
       : $self->{'_sql'} ? Pagesmith::Cache::SQL::release_lock(       $self->lock_details )
       : ()
       ;
}

sub is_free_lock {
  my $self = shift;
  return $self->{'_mem'} ? Pagesmith::Cache::Memcache::is_free_lock( $self->lock_details )
       : $self->{'_sql'} ? Pagesmith::Cache::SQL::is_free_lock(       $self->lock_details )
       : 1
       ;
}

sub is_used_lock {
  my $self = shift;
  return $self->{'_mem'} ? Pagesmith::Cache::Memcache::is_used_lock( $self->lock_details )
       : $self->{'_sql'} ? Pagesmith::Cache::SQL::is_used_lock(       $self->lock_details )
       : 0
       ;
}
## use critic
sub has_lock {
  my $self = shift;
  my $is_used = $self->is_used_lock;
  return $is_used == 1 ? 1 : 0;
}

1;

