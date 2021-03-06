package Pagesmith::Cache::SQL;

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

## SQL implementation of Cache
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
const my $MAX_SIZE => 5e6;
const my $MAX_SLEEP   => 0.02;
const my $MICRO_SLEEP => 0.001;
const my $CONN_RESET  => 600;

use DBIx::Connector;
use POSIX qw(ceil);
use English qw(-no_match_vars $EVAL_ERROR $PID);

use Pagesmith::Cache::Base qw(expires columns);

my $dbh_config = {
  'dsn'     => q(),
  'user'    => undef,
  'pass'    => q(),
  'options' => {},
  'last_connect' => undef,
};

my $dbh;

my $site_keys = {};

sub set_dsn {
  $dbh_config->{'dsn'} = shift;
  return;
}

sub set_user {
  $dbh_config->{'user'} = shift;
  return;
}

sub set_pass {
  $dbh_config->{'pass'} = shift;
  return;
}

sub add_option {
  my ( $k, $v ) = @_;
  $dbh_config->{'options'}{$k} = $v;
  return;
}

sub configured {
  return $dbh_config->{'dsn'} ? 1 : 0;
}

sub _new_cache {
  $dbh = DBIx::Connector->new( $dbh_config->{'dsn'}, $dbh_config->{'user'}, $dbh_config->{'pass'}, $dbh_config->{'options'} );
  $dbh->mode('fixup');
  $dbh_config->{'last_connect'} = time;
  $dbh->dbh;
  return;
}

sub _touch_cache {
  return _new_cache unless $dbh;
  if( time - $dbh_config->{'last_connect'} < $CONN_RESET ) {
    $dbh_config->{'last_connect'} = time;
    return;
  }
  undef $dbh;
  _new_cache;
  return;
}

sub _site_key {
  my $site_key = shift;
  _touch_cache;
  return unless $dbh;
  my $site_id = _scalar( 'select site_id from site where site_key = ?', $site_key );
  unless ($site_id) {
    _do( 'insert ignore into site (site_key) values(?)', $site_key );
    $site_id = _scalar( 'select site_id from site where site_key = ?', $site_key );
    $site_keys->{$site_key} = $site_id if $site_id;
  }
  return $site_id;
}

sub _parse_key {
  my $key = shift;
  my ( $table, $site_key, @pars ) = split m{[|]}mxs, $key;
  return if $table =~ m{\W}mxs;    ## Dodgy table name
  my @cols = columns( $table );
  return unless @cols;    ## Unknown table name...
  return unless @pars == @cols;
  my $site_id =
    exists( $site_keys->{$site_key} )
    ? $site_keys->{$site_key}
    : _site_key($site_key);
  return unless $site_id;
  my %return = (
    'table'   => $table, 'site_id' => $site_id, 'cols'    => \@cols,
    'pars'    => \@pars, 'where'   => join( '=? and ', @cols, 'expires_at > now()' ),
  );
  return \%return;
}

sub _scalar {
  my($sql,@pars) = @_;
  my $t;
  my $rv = eval {
    ($t) = $dbh->run( 'fixup' =>  sub { return $_->selectrow_array( $sql, {}, @pars ); } );
  };
  if( $EVAL_ERROR ) {
    warn "[$t] _scalar EVAL ERROR $PID/$ENV{CHILD_COUNT}:: $EVAL_ERROR $PID\n";
  }
  return $t;
}

sub _now {
  my($sql,@pars) = @_;
  my $t;
  my $rv = eval {
    ($t) = $dbh->run( 'fixup' =>  sub { return $_->selectrow_array( 'select now()', {}, @pars ); } );
  };
  if( $EVAL_ERROR ) {
    warn "[$t] _now EVAL ERROR $PID/$ENV{CHILD_COUNT}:: $EVAL_ERROR $PID\n";
  }
  return $t;
}

sub _do {
  my($sql,@pars) = @_;
  my $res;
  my $rv = eval {
    $res = $dbh->run( 'fixup' => sub { return $_->do( $sql, {}, @pars ); } );
  };
  if( $EVAL_ERROR ) {
    warn "[$res] _do EVAL ERROR $PID/$ENV{CHILD_COUNT}:: $EVAL_ERROR $PID\n";
  }
  return $res;
}

### These are the real functions!!!

##no critic (BuiltinHomonyms)
sub exists {
  my $key = shift;
  my $t   = _parse_key($key);
  return unless $t;
  return _scalar( "select 1 from $t->{'table'} where site_id = ? and $t->{'where'}", $t->{'site_id'}, @{ $t->{'pars'} } );
}
##use critic (BuiltinHomonyms)

sub get {
## Returns value of undef if not found!
## otherwise returns the content of the cache for this key
## and the time at which the data expires (so that when we
## do the propogation of cache results back to memcached
## it gets the right expiry time.
  my $key = shift;
  my $t   = _parse_key($key);
  return unless $t;
  _touch_cache;
  return unless $dbh;
  my ( $content, $expires ) = $dbh->run( 'fixup'=> sub { return $_->selectrow_array(
    "select content, unix_timestamp(expires_at) from $t->{'table'} where site_id = ? and $t->{'where'}",
    {}, $t->{'site_id'}, @{ $t->{'pars'} } ); });
  return unless $content;
  if ( $content =~ m{\A2(\d+)\Z}mxs ) {
    my @T    = @{ $t->{'pars'} };
    my $base = pop @T;
    $content = q();
    foreach ( 1 .. $1 ) {
      my $x = _scalar(
        "select content from $t->{'table'} where site_id = ? and $t->{'where'}",
        $t->{'site_id'}, @T, "$base:$_",
      );
      return unless defined $x;
      $content .= $x;
    }
  }
  return ( $content, $expires );
}

sub unset {    ## Returns value of undef if not found!
  my $key = shift;
  my $t   = _parse_key($key);
  return unless $t;
  _touch_cache;
  return unless $dbh;
  my $content = _scalar(
    "select left(content,20) from $t->{'table'} where site_id = ? and $t->{'where'}",
    $t->{'site_id'}, @{ $t->{'pars'} } );
  return unless defined $content;
  if ( $content =~ m{\A2(\d+)}mxs ) {
    my @T    = @{ $t->{'pars'} };
    my $base = pop @T;
    foreach ( 1 .. $1 ) {
      _do( "delete from $t->{'table'} where site_id = ? and $t->{'where'}", $t->{'site_id'}, @T, "$base:$_" );
    }
  }
  return _do( "delete from $t->{'table'} where site_id = ? and $t->{'where'}", $t->{'site_id'}, @{ $t->{'pars'} } );
}

sub touch {
  my ( $key, $expires ) = @_;
  my $t = _parse_key($key);
  return unless $t;
  _touch_cache;
  return unless $dbh;
  $expires = expires($expires);
  my $content =
    _scalar( "select left(content,20) from $t->{'table'} where site_id = ? and $t->{'where'}", $t->{'site_id'}, @{ $t->{'pars'} } );
  return unless $content;
  if ( $content =~ m{\A2(\d+)}mxs ) {
    my @T    = @{ $t->{'pars'} };
    my $base = pop @T;
    foreach ( 1 .. $1 ) {
      _do( "update $t->{'table'} set expires_at = from_unixtime(?) where site_id = ? and $t->{'where'}",
        $expires, $t->{'site_id'}, @T, "$base:$_" );
    }
  }

  return _do( "update $t->{'table'} set expires_at = from_unixtime(?) where site_id = ? and $t->{'where'}",
    $expires, $t->{'site_id'}, @{ $t->{'pars'} } );
}

##no critic (AmbiguousNames)
sub set {    ## Returns true if set was successful...
  my ( $key, $content, $expires ) = @_;
  return unless defined $content;    ## Must have content!

  my $t = _parse_key($key);
  return unless $t;            ## Dodgy key!
  _touch_cache;
  return unless $dbh;

  $expires = expires($expires);

  my $where = join( '=? and ', @{ $t->{'cols'} } ) . q(=?);

  my $f =
    _scalar( "select left(content,20) from $t->{'table'} where site_id = ? and $where", $t->{'site_id'}, @{ $t->{'pars'} } );
  if ( $f && $f =~ m{\A2(\d+)\Z}mxs ) {          ## Remove old blocks!!
    my @T    = @{ $t->{'pars'} };
    my $base = pop @T;
    foreach ( 1 .. $1 ) {
      _do( "delete from $t->{'table'} where site_id = ? and $t->{'where'}", $t->{'site_id'}, @T, "$base:$1" );
    }
  }
  my $now = _scalar('select now()');
  my $len = length $content;
  if ( $len > $MAX_SIZE ) {
    my $blocks = ceil( $len / $MAX_SIZE );
    my @T      = @{ $t->{'pars'} };
    my $base   = pop @T;
    foreach ( 1 .. $blocks ) {
      my $cols = join q(,), @{ $t->{'cols'} }, qw(created_at updated_at content);
      ( my $question_marks = $cols ) =~ tr{,}{?}cs;
      _do( "insert ignore into $t->{'table'} (site_id,$cols,expires_at) values ($question_marks,?,from_unixtime(?))",
        $t->{'site_id'}, @T, "$base:$_", $now, $now, substr( $content, ( $_ - 1 ) * $MAX_SIZE, $MAX_SIZE ), $expires );
    }
    $content = "2$blocks";
  } else {
    $content = $content;
  }
  if ($f) {    ## We already have an entry - so we update it!
    $f = _do( "update $t->{'table'} set updated_at = ?, expires_at = from_unixtime(?), content = ? where site_id = ? and $where",
      $now, $expires, $content, $t->{'site_id'}, @{ $t->{'pars'} } );
  } else {     ## We don't have an entry so create a new one!
    my $cols = join q(,), @{ $t->{'cols'} }, qw(created_at updated_at content);
    ( my $question_marks = $cols ) =~ tr{,}{?}cs;
    $f = _do(
      "insert ignore into $t->{'table'} (site_id,$cols,expires_at) values (?,$question_marks,from_unixtime(?))",
      $t->{'site_id'}, @{ $t->{'pars'} },
      $now, $now, $content, $expires,
    );
  }
  return $f;
}
##use critic (AmbiguousNames)

sub get_lock {
  my( $lock_key, $lock_val, $expiry, $timeout ) = @_;

  _touch_cache;
  return 1 unless $dbh; ## if can't get dbh then we have to assume lock is successful!

  my $mult = 0;
  my $end_timeout = time + $timeout;
  _do( 'insert ignore into lock_table (key,value,expiry) values(?,?,adddate(?, interval ? second))', $lock_key, q(), _now, $expiry );
  while( time < $end_timeout ) {
    my $flag = _do( 'update lock_table set value = ? where key = ? and expiry < now()' );
    return 1 if $flag;
    $mult++ if $mult < $MAX_SLEEP;
    sleep $MICRO_SLEEP * $mult;
  }
  return 0; ## Failed to get lock!
}

sub release_lock {
  my( $lock_key, $lock_val ) = @_;

  _touch_cache;
  return 1 unless $dbh; ## if can't get dbh then we have to assume release is successful!

  return _do( 'delete from lock_table where key = ? and value = ?', $lock_key, $lock_val ) ? 1 : 0;
}

sub is_free_lock {
#@return integer - 1 if lock is not used, 0 otherwise
  my( $lock_key, $lock_val ) = @_;

  _touch_cache;
  return 1 unless $dbh; ## if can't get dbh then we have to assume lock is free

  return _scalar( 'select value from lock_table where key = ?', $lock_key ) ? 1 : 0;
}

sub is_used_lock {
#@return integer - 1 if lock is used and is owned by this process, -1 if lock is used but not by this cache element, 0 if free
  my( $lock_key, $lock_val ) = @_;

  _touch_cache;
  return 0 unless $dbh; ## if can't get dbh then we have to assume lock is free

  my $actual_lock_val = _scalar(  'select value from lock_table where key = ?', $lock_key );
  return $actual_lock_val eq $lock_val ? 1
       : $actual_lock_val              ? - 1
       :                                 0
       ;
}

1;

__END__
= SQL create statement

  create table cachefile (
    sitename    varchar(64) not null,
    cachekey    varchar(64) not null,
    created_at  timestamp not null default current_timestamp,
    updated_at  timestamp not null,
    content     mediumblob not null,
    expires_at  timestamp not null default '2037-01-01 23:59:59',
    key site_key     (sitename,cachekey),
    key site_created (sitename,created_at),
    key expires_at   (expires_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1;

  create table component (
    sitename    varchar(64) not null,
    cachekey    varchar(64) not null,
    subkey      varchar(80) not
    created_at  timestamp not null default current_timestamp,
    updated_at  timestamp not null,
    content     mediumblob not null,
    expires_at  timestamp not null default '2037-01-01 23:59:59',
    key site_key     (sitename,cachekey),
    key site_created (sitename,created_at),
    key expires_at   (expires_at)
  ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
