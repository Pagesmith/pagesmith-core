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
use Sys::Hostname qw(hostname);
use English qw(-no_match_vars $PROGRAM_NAME);
use Scalar::Util qw(blessed weaken isweak);
use POSIX qw(floor);
use Const::Fast qw(const);

const my $DEFAULT_PORT => 3306;
const my $DEFAULT_HOST => 'localhost';
const my $DEFAULT_NAME => 'test';
const my $DEFAULT_TYPE => 'mysql';
const my $ONE_MEG      => 1<<20;

use Pagesmith::Iterator;
use Pagesmith::Config;
use Pagesmith::Core qw(user_info);
use base qw(Pagesmith::Support);

sub new {
#@constructor
#@param (class)
#@return (self)
  my( $class, $db_info, $r ) = @_;

  ## If db_info is empty - and just r $is passd then we shift the entries appropriately

  ($r,$db_info) = ($db_info,undef) if 'Apache2::RequestRec' eq ref $db_info; ## Yoda stops requirement for brackets

  my $self;
  if( blessed $db_info ) { ## DB info is an adaptor!
    $self = { map { ( $_ => $db_info->{$_} ) } qw(_conn _dsn _dbuser _dbpass _r _user _version _sub_class pool) };
    $self->{'_dbopts'} ||= {%{$db_info->{'_dbopts'}||{}}};
    bless $self, $class;
  } else { ## It is either "undefined" - so use connection_pars, scalar or hashref!
    $self = {
      '_conn'      => undef,
      '_dsn'       => undef,
      '_dbuser'    => undef,
      '_dbpass'    => undef,
      '_dbopts'    => undef,
      '_version'   => undef,
      '_r'         => $r,
      '_user'      => undef,
      '_sub_class' => undef,
      'pool'       => {},
    };
    bless $self, $class;                                        ## Original bless to put this in
                                                                ## the main adaptors name space...
    $db_info = $self->connection_pars unless defined $db_info; ## Now we get the database information if not passed
    $self->get_connection( $db_info )->connect_to_db;           ## and connect to the database
  }

  my $sub_class = $self->sub_class;
  if( $sub_class ) {                                    ## If we have a sub class defined - we may need to subclass
    my $msg = $self->rebless( $sub_class );
    ## no critic (RequireCarping)
    warn "UNABLE TO CREATE SUBCLASS - $msg" if $msg;
  }

  $self->init;   ## Run any additional code which is needed to set up the adaptor!

  return $self;  ## Return appropriately blessed object
}

## Stub functions to be overridden in subclass
sub connection_pars {
  my $self = shift;
  return $self->connection_pars;
}

sub init {
  my $self;
  return $self;
}

## Subclass/schema version/database server code!
sub sub_class {
  my $self = shift;
  return $self->{'_sub_class'};
}

sub schema_version {
  my $self = shift;
  return $self->{'_version'};
}

sub db_type { ## Return whether 'mysql', 'oracle' etc
  my $self = shift;
  my $dsn_type = $self->{'_dsn'} =~ m{\Adbi:(\w+)}mxs ? $1 : 'unknown';
  return lc $dsn_type;
}

sub is_type {
  my ( $self, $type ) = @_;
  return 'unknown' unless $self->{'_dsn'};
  my $dsn_type = $self->{'_dsn'} =~ m{\Adbi:(\w+)}mxs ? $1 : 'unknown';
  return $type eq lc $dsn_type;
}

## Now the connection code!

sub get_options {
  my( $self, $opts ) = @_;
  $opts||={};
  my $options                        = {( 'RaiseError' => 0, 'LongReadLen' => $ONE_MEG)};
     $options->{'mysql_enable_utf8'} = 1         if $self->is_type( 'mysql'  );
     $options->{'FetchHashKeyName'}  = 'NAME_lc' if $self->is_type( 'oracle' );
     $options->{$_} = $opts->{$_} foreach keys %{$opts};
  return $options;
}

sub get_connection {
  my( $self, $db_details ) = @_;

  if( $db_details && ! ref $db_details ) {
    my $pch = Pagesmith::Config->new( { 'file' => 'databases', 'location' => 'site' } );
    $pch->load( 1 );
    $db_details = $pch->get( $db_details );
  }
  return $self unless $db_details && 'HASH' eq ref $db_details;
  if( exists $db_details->{'host'} && $db_details->{'host'} =~ s{:(\d+)\Z}{}mxsg ) {
    $db_details->{'port'} ||= $1;
  }
  ( $db_details->{'host'} ||= $DEFAULT_HOST ) =~ s{[^-[.]\w]}{}mxgs;
  ( $db_details->{'type'} ||= $DEFAULT_TYPE ) =~ s{\W}{}mxgs;
  ( $db_details->{'port'} ||= $DEFAULT_PORT ) =~ s{\D}{}mxgs;
    $db_details->{'user'} ||= q();
    $db_details->{'pass'} ||= q();
  ( $db_details->{'name'} ||= $DEFAULT_NAME ) =~ s{[^-[.]\w]}{}mxgs;
    $db_details->{'dsn'}  ||= $self->generate_dsn( $db_details );

  $self->{'_dsn'}       = $db_details->{'dsn'};
  $self->{'_dbuser'}    = $db_details->{'user'};
  $self->{'_version'}   = $db_details->{'version'};
  $self->{'_dbpass'}    = $db_details->{'pass'};
  $self->{'_sub_class'} = $db_details->{'subclass'} || q();
  $self->{'_dbopts'}    = $self->get_options( $db_details->{'opts'} );
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
  return $self unless exists  $self->{'_dsn'} && $self->{'_dsn'};
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

##
sub conn {
  my $self = shift;
  return $self->{'_conn'};
}

sub dbh {
#@param (self);
#@return (DBI) database handle
  my $self = shift;
  return unless $self->{'_conn'};
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

sub code_block {
  my ( $self, $coderef ) = @_;
  return unless $self->conn;
  ## We will run these as a transaction!
  return $self->conn->txn( 'fixup' => $coderef );
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
  return $self->conn->run( 'fixup' =>  sub { return $_->selectall_arrayref( $sql, { 'Slice' => {} }, @pars ); } );
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

sub quote {
  my( $self, $str ) = @_;
  return $self->dbh->quote( $str );
}

sub realise_sql {
  my ( $self, $sql, @pars ) = @_;
  my @parts = split m{[?]}mxs, $sql, - 1;
  $sql = shift @parts;
  $sql .= $self->dbh->quote( shift @pars ).shift @parts  while @parts;
  return $sql;
}

## Logging/access information!

sub set_r {
  my( $self, $r ) = @_;
  $self->{'_r'} = $r;
  return $self;
}

sub r {
  my $self = shift;
  return $self->{'_r'};
}

sub set_ip_and_useragent {
  my( $self, $object_to_update ) = @_;
  if( exists $self->{'_r'} && $self->r ) {
    $object_to_update->set_ip(
      $self->r->headers_in->{'X-Forwarded-For'} ||
      $self->remote_ip,
    );
    $object_to_update->set_useragent( $self->r->headers_in->{'User-Agent'} || q(--) );
  } else {
    my $host = hostname() || 'localhost';
    $object_to_update->set_ip( inet_ntoa( scalar gethostbyname $host ) );
    $object_to_update->set_useragent( "$ENV{q(SHELL)} $PROGRAM_NAME" );
  }
  return $self;
}

sub set_user {
  my ($self,$user) = @_;
  $self->{'_user'} = $user;
  return $self;
}

sub user {
  my $self = shift;
  unless( defined $self->{'_user'} ) {
    my $t_user = user_info();
    $self->{'_user'} = $t_user->{'username'};
  }
  return $self->{'_user'};
}

## Pooling support
sub add_self_to_pool {
  my( $self, $key ) = @_;
  $self->{'pool'}{$key} = $self;
  weaken $self->{'pool'}{$key};
  return $self;
}

sub get_adaptor_from_pool {
  my( $self, $key ) = @_;
  return $self->{'pool'}{$key};
}

sub get_iterator {
#@params (self) (string sql) (string params)*
#@return (self)
## Gets a new "iterator" statement handle for SQL statement (and parameters) provided
##
## Clears previous iterator if one exists to keep things tidy (should never need to!)
  my( $self, $sql, @params ) = @_;

  my $sth = $self->dbh->prepare( $sql ); ## Prepare and execute SQL and store iterator!
  return unless $sth;
  $sth->execute( @params );
  return Pagesmith::Iterator->new( $sth );
}

sub dsn {
  my $self = shift;
  return $self->{'_dsn'};
}
sub dbuser {
  my $self = shift;
  return $self->{'_dbuser'};
}
sub dbpass {
  my $self = shift;
  return $self->{'_dbpass'};
}

sub get_results_sql_generic {
  my ($self, $params, $parts ) = @_;

  my $limit = $params->{'size'};
  my $start = $limit * $params->{'page'};
     $start = 0 if $start < 0;

  my @sql_params;
  ## As we are using
  my $where_sql = $self->get_where_sql(
    $params->{'filter'}||[],
    $parts->{'columns'}||{},
    \@sql_params,
    $parts->{'where'}||q(),
  );

  ## Short cut to no rows if we know this will return nothing!
  ## get_where_sql returns nothing if one of the restrictions is blank!
  return unless defined $where_sql;

  return {
    'c_sql' => "select count(*) from $parts->{'from'} $where_sql",
    'pars'  => \@sql_params,
    'start' => $start,
    'size'  => $limit,
    'sql'   => join q( ),
               'select', $parts->{'select'},
               'from',   $parts->{'from'},
               $where_sql,
               $self->get_order_by_sql( $params->{'sort_list'}||[] ),
  };
}

sub get_where_sql {
  my( $self, $filters, $col_defs, $params, $where_sql ) = @_;
  my @parts;
  push @parts, $where_sql if $where_sql;
  foreach my $col ( @{$filters||[]} ) {
    ## Looking at filters - we have to handle the tech & state ones differently as they
    ## cannot be used in count as the aliased names! - the alternate SQL is in the COL_DEFS
    ## hash above!
    my $exp = exists $col_defs->{$col->[0]} ? $col_defs->{$col->[0]} : $col->[0];

    if( 'CODE' eq ref $exp ) {
      my ($sql, @pars) = &{$exp}($self, $col->[1]);
      return unless $sql;
      push @parts, $sql;
      push @{$params}, @pars;
    } else {
      if( $col->[1] =~ m{\A([<>]|[!<>]?=)\s*(.*)\Z}mxs ) {
        push @parts, "$exp $1 ?";
        push @{$params}, $2;
      } elsif( $col->[1] =~ m{\A!\s*(.*)\Z}mxs ) {
        push @parts, "$exp not like ?";
        push @{$params}, "%$1%";
      } else {
        push @parts, "$exp like ?";
        push @{$params}, "%$col->[1]%";
      }
    }
  }
  return q() unless @parts;
  return "\n     where ".join "\n       and ", @parts;
}

sub get_order_by_sql {
  my( $self, $sort_list ) = @_;
  return q() unless @{$sort_list||[]};
  return "\n     order by". join q(, ),
    map { sprintf ' %s %s', $_->[0], $_->[1]>0 ? 'desc' :'asc' }
    @{$sort_list};
}

sub count_and_hash {
#@params (self, hashref details)
#@returns ( Int, hashref[] ) total count of rows, slice or rows...
## details has five (or 6) entries in it..
## * string c_sql  - Count SQL
## * string sql    - Real SQL
## * int    size   - Size of slice to return
## * int    start  - First row to return
## * string[] pars - parameters to pass to slice SQL (and count if c_pars isn't defined)
## * string[] c_pars (optional) - parameters to pass to count SQL

  my ($self, $details) = @_;
  return ( 0, [] ) unless $details;
  my $count   = $self->sv( $details->{'c_sql'}, @{ exists $details->{'c_pars'}  ? $details->{'c_pars'} :  $details->{'pars'}} );

  $details->{'start'} = $details->{'size'} * floor( $count/$details->{'size'} ) if $details->{'start'} > $count;

  my $rows = $self->all_hash( "$details->{'sql'} limit $details->{'start'}, $details->{'size'}",
    @{$details->{'pars'}} );

  return ( $count, $rows );
}


1;

