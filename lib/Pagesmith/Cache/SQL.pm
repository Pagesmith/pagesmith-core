package Pagesmith::Cache::SQL;

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

use Readonly qw(Readonly);
Readonly my $MAX_SIZE => 5e6;

use DBIx::Connector;
use POSIX qw(ceil);

use Pagesmith::Cache::Base qw(_expires _columns);

my $dbh_config = {
  'dsn'     => q(),
  'user'    => undef,
  'pass'    => q(),
  'options' => {},
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
  $dbh_config->{$k} = $v;
  return;
}

sub configured {
  return $dbh_config->{'dsn'} ? 1 : 0;
}

sub _new_cache {
  $dbh = DBIx::Connector->new( $dbh_config->{'dsn'}, $dbh_config->{'user'}, $dbh_config->{'pass'}, $dbh_config->{'options'} );
  $dbh->mode('fixup');
  $dbh->dbh;
  return;
}

sub _site_key {
  my $site_key = shift;
  _new_cache unless $dbh;
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
  my ( $table, $site_key, @pars ) = split m{\|}mxs, $key;
  return if $table =~ m{\W}mxs;    ## Dodgy table name
  my @cols = _columns( $table );
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
  my ($t) = $dbh->run( 'fixup' =>  sub { return $_->selectrow_array( $sql, {}, @pars ); } );
  return $t;
}

sub _do {
  my($sql,@pars) = @_;
  return $dbh->run( 'fixup' => sub { return $_->do( $sql, {}, @pars ); } );
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
  _new_cache unless $dbh;
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
  _new_cache unless $dbh;
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
  _new_cache unless $dbh;
  return unless $dbh;
  $expires = _expires($expires);
  my $content =
    _scalar( "select left(content,20) from $t->{'table'} where site_id = ? and $t->{'where'}", $t->{'site_id'}, @{ $t->{'pars'} } );
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
  $dbh ||= _new_cache;
  return unless $dbh;

  $expires = _expires($expires);

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
