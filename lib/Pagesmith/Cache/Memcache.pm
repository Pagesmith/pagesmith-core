package Pagesmith::Cache::Memcache;

## Shared network memory cache
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
const my $MAX_SIZE => 1e6;
use Time::HiRes qw(time);
use Cache::Memcached::Tags;
use POSIX qw(ceil);

use Const::Fast qw(const);
const my $MAX_SLEEP   => 0.02;
const my $MICRO_SLEEP => 0.001;
use Pagesmith::Cache::Base qw(expires columns);
use Encode;

my $memd_config = { 'servers' => [], 'debug' => 'off' };
my $server_keys = {};
my $memd;

sub configured {
  return @{ $memd_config->{'servers'} } ? 1 : 0;
}

sub add_server {
  my( $server, @pars ) = @_;
  $server .= ':11211' unless $server =~ m{[:\/]}mxs;
  return if $server_keys->{$server};
  $server_keys->{$server} = 1;
  push @{ $memd_config->{'servers'} }, ( @pars && $pars[0] != 1 ) ? [$server, $pars[0]] : $server;
  return;
}

sub add_option {
  my ( $k, $v ) = @_;
  $memd_config->{$k} = $v;
  return;
}

sub _new_cache {
  return Cache::Memcached::Tags->new( $memd_config );
}

sub get {    ## Returns value of undef if not found!
  $memd ||= _new_cache;
  return unless $memd;
  my $key     = shift;
  my $content = $memd->get($key);
  return unless $content;
  Encode::decode_utf8($content);
  if ( $content =~ m{\A2(\d+)\Z}mxs ) {    ## We have a large file!
    my @keys = map { $key . q(-) . $_ } 1 .. $1;
    my $y = $memd->get_multi(@keys);
    $content = q();
    foreach (@keys) {
      return unless $y->{$_};
      $content .= $y->{$_};
    }
  }

  return $content;
}

##no critic (AmbiguousNames);
sub set {    ## Returns true if set was successful...
  my ( $key, $content, $expires ) = @_;
  Encode::encode_utf8($content);
  $memd ||= _new_cache;
  return unless $memd;
  $expires = expires($expires);
  return unless defined $content;
  my @t = split m{[|]}mxs, $key;
  my @cols = columns($t[0]);
  return unless @cols;   ## Unknown table name...
  my @keys = ( 'category', 'sitekey', @cols );
  my @tags = map { ( shift @keys ) . q(:) . $_ } @t;

  my $len = length $content;

  if ( $len > $MAX_SIZE ) {
    my $blocks = ceil( $len / $MAX_SIZE );
    my $v = $memd->set( $key, "2$blocks", $expires, @tags );
    foreach my $block_no ( 1 .. $blocks ) {
      $memd->set( "$key-$block_no", substr( $content, ( $block_no - 1 ) * $MAX_SIZE, $MAX_SIZE ), $expires, @tags );
    }
    return $v;
  } else {
    my $v = $memd->set( $key, $content, $expires, @tags );
    return $v;
  }
}
##use critic (AmbiguousNames);

sub unset {
  $memd ||= _new_cache;
  return unless $memd;
  my $key     = shift;
  my $content = $memd->get($key);
  return $memd->delete($key) unless $content;

  if( $content =~ m{\A2(\d+)\Z}mxs ) {
    my @keys = map { $key . q(:) . $_ } 1 .. $1;
    foreach (@keys) {
      $memd->delete($_);
    }
  }
  return $memd->delete($key);
}

sub touch {
  my ( $key, $expires ) = @_;
  $memd ||= _new_cache;
  return unless $memd;
  my $content = $memd->get($key);
  return unless defined $content;
  $expires = expires($expires);
  if ( $content =~ m{\A2(\d+)\Z}mxs ) {
    my @keys = map { $key . q(:) . $_ } 1 .. $1;
    my $y = $memd->get_multi(@keys);
    foreach (@keys) {
      return unless $y->{$_};
    }
    foreach (@keys) {
      $memd->set( $_, $y->{$_}, $expires );
    }
  }
  return $memd->set( $key, $content, $expires );
}

##no critic (BuiltinHomonyms)
sub exists {
  $memd ||= _new_cache;
  return unless $memd;
  my $key = shift;
  return $memd->get($key) ? 1 : 0;
}
##use critic (BuiltinHomonyms)

sub get_lock {
  my( $lock_key, $lock_val, $expiry, $timeout ) = @_;
  $memd ||= _new_cache;
  return 1 unless $memd; ## if can't get memcached then we have to assume lock is successful!
  my $mult = 0;
  my $end_timeout = time + $timeout;
  while( time < $end_timeout ) {
    $memd->add( $lock_key, $lock_val, $expiry );
    my $actual_lock_val = $memd->get( $lock_key );
    return 1 if $actual_lock_val eq $lock_val; ## Yes we have the lock!
    $mult++ if $mult < $MAX_SLEEP;
    sleep $MICRO_SLEEP * $mult;
  }
  return 0; ## Failed to get lock!
}

sub release_lock {
  my( $lock_key, $lock_val ) = @_;
  $memd ||= _new_cache;
  return 1 unless $memd; ## if can't get memcached then we have to release is successful!
  my $actual_lock_val = $memd->get( $lock_key );
  if( $actual_lock_val eq $lock_val ) {
    $memd->delete;
    return 1;
  } else {
    return 0;
  }
}

sub is_free_lock {
#@return integer - 1 if lock is not used, 0 otherwise
  my( $lock_key, $lock_val ) = @_;
  $memd ||= _new_cache;
  return 1 unless $memd; ## if can't get memcached then we have to assume lock is free
  my $actual_lock_val = $memd->get( $lock_key );
  return $actual_lock_val ? 0 : 1;
}

sub is_used_lock {
#@return integer - 1 if lock is used and is owned by this process, -1 if lock is used but not by this cache element, 0 if free
  my( $lock_key, $lock_val ) = @_;
  $memd ||= _new_cache;
  return 0 unless $memd; ## if can't get memcached then we have to assume lock is free
  my $actual_lock_val = $memd->get( $lock_key );
  return $actual_lock_val eq $lock_val ? 1
       : $actual_lock_val              ? - 1
       :                                 0
       ;
}

1;

