package Pagesmith::Adaptor;

## Base class for other web-adaptors...
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

## Supplies wrapper functions for DBI

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use DBIx::Connector;

## The following are used to fake useragent/ip if called from a script!

use Socket qw(inet_ntoa);
use Sys::Hostname::Long qw(hostname_long);
use English qw(-no_match_vars $PROGRAM_NAME);
use Scalar::Util qw(blessed weaken isweak);

use Readonly qw(Readonly);

Readonly my $DEFAULT_PORT => 3306;
Readonly my $DEFAULT_HOST => 'localhost';
Readonly my $DEFAULT_NAME => 'test';
Readonly my $DEFAULT_TYPE => 'mysql';
Readonly my $ONE_MEG      => 1<<20;

use Pagesmith::Config;
use Pagesmith::Core qw(user_info);
use base qw(Pagesmith::Support);

sub _connection_pars {
  return ();
}

sub set_user {
  my ($self,$user) = @_;
  $self->{'_user'} = $user;
  return $self;
}

sub schema_version {
  my $self = shift;
  return $self->{'_version'};
}
sub user {
  my $self = shift;
  unless( defined $self->{'_user'} ) {
    my $t_user = user_info();
    $self->{'_user'} = $t_user->{'username'};
  }
  return $self->{'_user'};
}

sub is_type {
  my ( $self, $type ) = @_;
  my $dsn_type = $self->{'_dsn'} =~ m{\Adbi:(\w+)}mxs ? $1 : 'unknown';
  return $type eq lc $dsn_type;
}

sub get_connection {
  my( $self, $db_details ) = @_;

  if( $db_details && ! ref $db_details ) {
    my $pch = Pagesmith::Config->new( { 'file' => 'databases', 'location' => 'site' } );
    $pch->load( 1 );
    $db_details = $pch->get( $db_details );
  }
  return $self unless $db_details;
  ( $db_details->{'host'} ||= $DEFAULT_HOST ) =~ s{[^-\.\w]}{}mxgs;
  ( $db_details->{'type'} ||= $DEFAULT_TYPE ) =~ s{\W}{}mxgs;
  ( $db_details->{'port'} ||= $DEFAULT_PORT ) =~ s{\D}{}mxgs;
    $db_details->{'user'} ||= q();
    $db_details->{'pass'} ||= q();
  ( $db_details->{'name'} ||= $DEFAULT_NAME ) =~ s{[^-\.\w]}{}mxgs;
    $db_details->{'dsn'}  ||= $self->generate_dsn( $db_details );

  $self->{'_dsn'}    = $db_details->{'dsn'};
  $self->{'_dbuser'} = $db_details->{'user'};
  $self->{'_version'} = $db_details->{'version'};
  $self->{'_dbpass'} = $db_details->{'pass'};
  $self->{'_dbopts'} = $db_details->{'opts'} || {( 'RaiseError' => 0, 'LongReadLen' => $ONE_MEG )};
  return $self;
}

sub generate_dsn {
  my( $self, $db_details ) = @_;
  return "dbi:$db_details->{'type'}:database=$db_details->{'name'};host=$db_details->{'host'};port=$db_details->{'port'}";
}

sub connect_to_db {
  my( $self, $force ) = @_;
  $self->disconnect_db if $force && defined $self->{'_conn'};
  return $self if $self->{'_conn'};
  $self->{'_conn'} = DBIx::Connector->new( $self->{'_dsn'}, $self->{'_dbuser'}, $self->{'_dbpass'}, $self->{'_dbopts'} );
  $self->{'_conn'}->mode( 'fixup' );
  return $self;
}

sub disconnect_db {
  my $self = shift;
  return $self unless $self->{'_conn'};
  $self->dbh->disconnect;
  undef $self->{'_conn'};
  return $self;
}

sub set_r {
  my( $self, $r ) = @_;
  $self->{'_r'} = $r;
  return $self;
}

sub r {
  my $self = shift;
  return $self->{'_r'};
}

sub new {
#@constructor
#@param (class)
#@return (self)
  my( $class, $db_info, $r ) = @_;

  ($r,$db_info) = ($db_info,undef) if 'Apache2::RequestRec' eq ref $db_info;

  if( blessed $db_info ) { ## DB info is an adaptor!
    my $self = { map { ( $_ => $db_info->{$_} ) } qw(_conn _dsn _dbuser _dbpass _r _user _version pool) };
    $self->{'_dbopts'} ||= {%{$db_info->{'_dbopts'}}};
    bless $self, $class;
    return $self;
  }
  my $self = {
    '_conn'   => undef,
    '_dsn'    => undef,
    '_dbuser' => undef,
    '_dbpass' => undef,
    '_dbopts' => undef,
    '_r'      => $r,
    '_user'   => undef,
    'pool'    => {},
  };
  bless $self, $class;
  $db_info = $self->_connection_pars unless defined $db_info;
  $self->get_connection( $db_info )->connect_to_db;
  return $self;
}

sub add_self_to_pool {
  my( $self, $key );
  $self->{'pool'}{$key} = $self;
  weaken $self->{'pool'}{$key};
  return $self;
}

sub get_adaptor_from_pool {
  my( $self, $key );
  return $self->{'pool'}{$key};
}

sub conn {
  my $self = shift;
  return $self->{'_conn'};
}

sub dbh {
#@param (self);
#@return (DBI) database handle
  my $self = shift;
  return $self->{'_conn'}->dbh;
}

sub prepare {
  my( $self, @params ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub { return $_->prepare( @params ); } );
}

sub sv {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  my ($res) = $self->conn->run( 'fixup' =>  sub { return $_->selectrow_array( $sql, {}, @pars ); } );
  return $res;
}

sub row {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub { return $_->selectrow_arrayref( $sql, {}, @pars ); } );
}

sub row_hash {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub { return $_->selectrow_hashref( $sql, {}, @pars ); } );
}

sub all {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub { return $_->selectall_arrayref( $sql, {}, @pars ); } );
}

sub all_hash {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  return return $self->conn->run( 'fixup' =>  sub { return $_->selectall_arrayref( $sql, { 'Slice' => {} }, @pars ); } );
}

sub query {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub { return $_->do( $sql, {}, @pars ); });
}

sub insert {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, $table_name, $column, @pars ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub {
    return unless $_->do( $sql, {}, @pars );
    return $_->last_insert_id( undef, undef, $table_name, $column );
  });
}


sub col {

#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub {
    return $_->selectcol_arrayref( $sql, {}, @pars );
  });
}

sub hash {
#@param (self);
#@param (string) $sql SQL
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, @pars ) = @_;
  return unless $self->conn;
  return $self->conn->run( 'fixup' =>  sub {
    return { map { @{$_} } @{ $_->selectall_arrayref( $sql, { 'Columns' => [1,2] }, @pars ) } };
  });
}

sub hash_hash {

#@param (self);
#@param (string) $sql SQL
#@param (string) $column to use as key
#@param (?)+ parameters to pass to SQL statement.
  my ( $self, $sql, $column, @pars ) = @_;
  return unless $self->conn;
  return return $self->conn->run( 'fixup' =>  sub {
    return $_->selectall_hashref( $sql, $column, {}, @pars );
  });
}

sub now {
#@param (self);
#@return (string) current mysql time stamp;
  my $self = shift;
  return $self->sv( 'select now()' );
}

sub realise_sql {
  my ( $self, $sql, @pars ) = @_;
  my @parts = split m{\?}mxs, $sql, - 1;
  $sql = shift @parts;
  $sql .= $self->dbh->quote( shift @pars ).shift @parts  while @parts;
  return $sql;
}

sub set_ip_and_useragent {
  my( $self, $object_to_update ) = @_;
  if( exists $self->{'_r'} && $self->r ) {
    $object_to_update->set_ip(
      $self->r->headers_in->{'X-Forwarded-For'} ||
      $self->r->connection->remote_ip,
    );
    $object_to_update->set_useragent( $self->r->headers_in->{'User-Agent'} || q(--) );
  } else {
    my $host = hostname_long() || 'localhost';
    $object_to_update->set_ip( inet_ntoa( scalar gethostbyname $host ) );
    $object_to_update->set_useragent( "$ENV{q(SHELL)} $PROGRAM_NAME" );
  }
  return $self;
}
1;
