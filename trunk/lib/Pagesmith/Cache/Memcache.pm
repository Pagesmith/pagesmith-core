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

use Readonly qw(Readonly);
Readonly my $MAX_SIZE => 1e6;
use Time::HiRes qw(time);
use Cache::Memcached::Tags;
use POSIX qw(ceil);

use Pagesmith::Cache::Base qw(_expires _columns);

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
  $memd ||= _new_cache;
  return unless $memd;
  $expires = _expires($expires);
  #printf {*STDERR} "SETTING TO %s ... %s [%s] %d\n", $memd, $key, $expires, length $content;
  return unless defined $content;
  my @t = split m{\|}mxs, $key;
  my @cols = _columns($t[0]);
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
    #printf {*STDERR} "SETTING %s -> %d bytes (%s)\n", $key, $len, "@tags";
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
  $expires = _expires($expires);
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
1;

