package Pagesmith::AdaptorMethods;

## Base class for auto-creating methods from configuration...!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Thu, 23 Jan 2014
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');
use feature qw(switch);
use Const::Fast qw(const);

const my $DEFAULTS => {
  'number'  => 0,
  'boolean' => 'no',
};

## This will need our standard get other adaptor method call!

## Functions to define accessors for objects....

sub create_method {
  my ( $pkg, $fn, $sub ) = @_;
  my $method = $pkg.q(::).$fn;
  no strict 'refs'; ## no critic (NoStrict)
  if( defined &{$method} ) {
    warn qq(Method "$fn" already exists on $pkg - defining "_$fn"\n);
    $fn= "_$fn";
    $method = $pkg.q(::).$fn;
  }
  if( 'CODE' eq ref $sub ) {
    *{$method} = $sub;
  } else {
    *{$method} = eval $sub; ## no critic (StringyEval)
  }
  use strict;
  return $fn;
}

sub make_rel_methods {

}

## no critic (ExcessComplexity)
sub make_methods {
  my( $pkg, $config ) = @_;
  my @methods;
  ( my $obj_pkg = $pkg ) =~ s{Pagesmith::Adaptor}{Pagesmith::Object}mxs;
  ## Main object properties
  my $type         = $config->{'type'};
  my $singular     = lc $config->{'type'};
  my $plural       = exists $config->{'plural'} ? $config->{'plural'} : $singular.'s';
  my $props        = $config->{'properties'};
  my $make_method  = 'make_'.lc $type;

  my $derived_tables;
  my @create_audit_columns;
  my @update_audit_columns;
  my $create_audit_functions = q();
  my $update_audit_functions = q();
  my ($uid_column) = grep { 'uid' eq (ref $props->{$_} ? $props->{$_}{'type'} : $props->{$_} ) } keys %{$props};
  my @columns      = grep { 'uid' ne (ref $props->{$_} ? $props->{$_}{'type'} : $props->{$_} ) } keys %{$props};

  ## no critic (InterpolationOfMetachars)
  if( exists $config->{'audit'} ) { ## We need to add audit columns!!
    if( exists $config->{'audit'}{'user_id'} ) {
      if( $config->{'audit'}{'user_id'} ne 'update' ) {
        push @create_audit_columns, 'created_by_id';
        $create_audit_functions .= '$o->set_created_by_id( $self->user_id );';
      }
      if( $config->{'audit'}{'user_id'} ne 'create' ) {
        push @update_audit_columns, 'updated_by_id';
        $update_audit_functions .= '$o->set_updated_by_id( $self->user_id );';
      }
    }
    if( exists $config->{'audit'}{'user'} ) {
      if( $config->{'audit'}{'user'} ne 'update' ) {
        push @create_audit_columns, 'created_by';
        $create_audit_functions .= '$o->set_created_by( $self->user_name );';
      }
      if( $config->{'audit'}{'user'} ne 'create' ) {
        push @update_audit_columns, 'updated_by';
        $update_audit_functions .= '$o->set_updated_by( $self->user_name );';
      }
    }
    if( exists $config->{'audit'}{'datetime'} ) {
      if( $config->{'audit'}{'datetime'} ne 'update' ) {
        push @create_audit_columns, 'created_at';
        $create_audit_functions .= '$o->set_created_at( $self->now );';
      }
      if( $config->{'audit'}{'datetime'} ne 'create' ) {
        push @update_audit_columns, 'updated_at';
        $update_audit_functions .= '$o->set_updated_at( $self->now );';
      }
    }
    if( exists $config->{'audit'}{'ip'} ) {
      if( $config->{'audit'}{'ip'} ne 'update' ) {
        push @create_audit_columns, 'created_ip';
        $create_audit_functions .= '$o->set_created_ip( $self->user_ip );';
      }
      if( $config->{'audit'}{'ip'} ne 'create' ) {
        push @update_audit_columns, 'updated_ip';
        $update_audit_functions .= '$o->set_updated_ip( $self->user_ip );';
      }
    }
    if( exists $config->{'audit'}{'useragent'} ) {
      if( $config->{'audit'}{'useragent'} ne 'update' ) {
        push @create_audit_columns, 'created_useragent';
        $create_audit_functions .= '$o->set_created_useragent( $self->user_useragent );';
      }
      if( $config->{'audit'}{'useragent'} ne 'create' ) {
        push @update_audit_columns, 'updated_useragent';
        $update_audit_functions .= '$o->set_updated_useragent( $self->user_useragent );';
      }
    }
  }
  ## use critic
  if( exists $config->{'related'} ) { ## We need to add audit columns!!
    foreach my $k ( keys  %{$config->{'related'}}) {
      my $conf = $config->{'related'}{$k};
      if( exists $conf->{'to'} && exists $conf->{'derived'} ) {
        $derived_tables->{$k}{$_} = $conf->{'derived'}{$_} foreach keys %{$conf->{'derived'}};
      }
    }
  }
  #use Data::Dumper qw(Dumper); warn '!pre!'. Dumper( $config );
  my $full_column_names = join q(, ), map { "o.$_" } $uid_column, @columns;
  my $table_map = {};
  my $tid = 0;
  foreach my $key_column (sort keys %{$derived_tables} ) {
    $full_column_names  .= ", o.$key_column";
    my $table_name = lc $config->{'related'}{$key_column}{'to'};
    $tid++;
    $table_map->{$key_column} = [ $table_name, "t$tid" ];
    $full_column_names .= join q(),
                          map  { ", t$tid.$_ ".$derived_tables->{$key_column}{$_} }
                          keys %{$derived_tables->{$key_column}};
  }
  my $audit_column_names = join q(), map { ", o.$_" } @create_audit_columns, @update_audit_columns;
  my $select_tables      = join q(), "$singular o",
    map { sprintf ') left join %s %s on o.%s = %s.%s_id',
      $table_map->{$_}[0], $table_map->{$_}[1], $_, $table_map->{$_}[1], $table_map->{$_}[0],
    } sort keys %{$table_map};
  $select_tables = ( '(' x scalar keys %{$table_map} ).$select_tables;

  push @methods,

    ## Light weight creator methods!

    create_method( $pkg, $make_method, sub {
      my($self,$hashref,$partial)=@_;
      return $obj_pkg->new( $self, $hashref, $partial );
    } ),
    create_method( $pkg, 'create', sub {
      my $self = shift;
      return $self->$make_method({});
    }),

    ## Fns to get column/table name lists out to allow other queries to get
    ## all object data!

    create_method( $pkg, 'full_column_names',   sub { return $full_column_names;  } ),
    create_method( $pkg, 'audit_column_names',  sub { return $audit_column_names; } ),
    create_method( $pkg, 'select_tables',       sub { return $select_tables;      } ),

    ## Writing content back to the database!

    create_method( $pkg, 'store', sub {
      my( $self, $o ) = @_;
      return if $o->is_partial;
      return $self->update_obj( $o ) if $o->uid;
      return $self->store_obj(  $o );
    } ),
## no critic (InterpolationOfMetachars)
    create_method( $pkg, 'store_obj', sprintf q(
sub {
  my( $self, $o ) = @_;
  %5$s
  return $o->set_%1$s_id( $self->insert( '
    insert into %1$s (
             %2$s
           ) values(
             %3$s
           )',
    '%1$s', '%1$s_id',
    %4$s ) );
}), $singular,
      ( join qq(,\n             ), @columns, @create_audit_columns ),
      ( join q(,), map { q(?) } @columns, @create_audit_columns ),
      ( join qq(,\n     ), map { sprintf '$o->get_%s', $_ } @columns, @create_audit_columns ),
      $create_audit_functions,
    ),
    create_method( $pkg, 'update_obj', sprintf q(
sub {
  my( $self, $o ) = @_;
  %5$s
  return $o->set_%1$s_id( $self->insert( '
    update %1$s
       set %2$s
     where %3$s = ?',
     %4$s,
    $o->uid ) );
}), $singular,
      ( join qq(,\n           ), map { $_.q( = ?) } @columns, @update_audit_columns ),
      $uid_column,
      ( join qq(,\n    ), map { sprintf '$o->get_%s', $_ } @columns, @update_audit_columns ),
      $update_audit_functions,
    ),
## use critic

    ## Fetch all and fetch 1 methods....

    create_method( $pkg, 'fetch_all_'.$plural, sub {
      my $self = shift;
      return [ map { $self->$make_method( $_ ) } @{$self->all_hash(
        'select '.$self->full_column_names.$self->audit_column_names.'
           from '.$self->select_tables.'
           order by o.'.$uid_column )||[] } ];
    } ),
    create_method( $pkg, 'fetch_'.$singular, sub {
      my ( $self, $uid ) = @_;
      my $t = $self->row_hash(
          'select '.$self->full_column_names.$self->audit_column_names.'
             from '.$self->select_tables.'
            where o.'.$uid_column.' = ?', $uid );
      return $self->$make_method( $t ) if $t;
      return;
    } ),
    ;
    ## We need to add any additional auto generated methods that are required here!

  ## Finally update a method which returns all the updated methods...

  create_method( $pkg, 'auto_methods', sub { my @m = sort @methods; return @m; });

  return;
}
## use critic

## Functions that munge the object configuration structure
## Merge in relationships!

1;
