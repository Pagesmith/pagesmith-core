package Pagesmith::Utils::ObjectCreator;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
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
use Pagesmith::Root;
use base qw(Exporter);
use Pagesmith::Utils::Wrap;
use List::Util qw(pairgrep pairmap pairfirst pairs);
use English qw(-no_match_vars $EVAL_ERROR);

our @EXPORT_OK = qw(bake bake_base_adaptor);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

const my $DEFAULTS => {
  'number'  => 0,
  'boolean' => 'no',
};

const my $LINE_WIDTH => 120;
const my $LHS_WIDTH  => 53;
my $root = Pagesmith::Root->new;

## This will need our standard get other adaptor method call!

## Functions to define accessors for objects....

sub bake {
  my( @pars ) = @_;
  my $pkg = caller 0;
  my ($type) = $pkg =~ m{\APagesmith::(\w+)}mxs;
  my $base_pkg = $pkg;
  if( $type eq 'Object' || $type eq 'Adaptor' ) { ## OT bake!
    my ($ns,$ot,$config,$mail_domain);
    unless( @pars ) {
      ( $ns, $ot ) = $pkg =~ m{(.*)::(.*)}mxs;
      $ns =~ s{\APagesmith::(?:Object|Adaptor)}{Pagesmith::Model}mxs;
      my $mail_method = $ns.'::mail_domain';
      $ns.='::type_defn';
      no strict 'refs'; ## no critic (NoStrict)
      $mail_domain = &{$mail_method}( );
      $config      = &{$ns}( $ot );
      $type = 'Relationship' if $type eq 'Adaptor' && $config->{'type'} eq 'relationship';
      use strict;
    } elsif( ! ref $pars[0] ) {
      $ot = $pars[0];
      ($ns = substr $pkg,0,- length $ot) =~ s{\APagesmith::(?:Object|Adaptor)}{Pagesmith::Model}mxs;
      my $mail_method = $ns.'mail_domain';
      $ns .='type_defn';
      no strict 'refs'; ## no critic (NoStrict)
      $config      = &{$ns}(      $ot );
      $mail_domain = &{$mail_method}( );
      use strict;
    } else {
      ($config, $ot, $mail_domain) = @pars;
    }
    return bake_object(        $pkg, $config, $ot ) if $type eq 'Object';
    return bake_relationship(  $pkg, $config, $ot, $mail_domain ) if $type eq 'Relationship';
    return bake_adaptor(       $pkg, $config, $ot, $mail_domain ); ## This will further delegate to rel...
  }

  return bake_model( $pkg, @pars ) if $type eq 'Model';
  return bake_support( $pkg ) if $type eq 'Support';
  warn qq(Unknown object type "$type"\n);
  return;
}

sub create_method {
  my ( $pkg, $fn, $sub, $defn, $flag ) = @_;
  my $method = $pkg.q(::).$fn;
  no strict 'refs'; ## no critic (NoStrict)
  if( defined &{$method} ) {
    return if defined $flag && $flag eq 'no_std';
    warn qq(Method "$fn" already exists on $pkg - defining "std_$fn"\n);
    $fn = "std_$fn";
    $method = $pkg.q(::).$fn;
  }
  if( 'CODE' eq ref $sub ) {
    *{$method} = $sub;
  } else {
    *{$method} = eval $sub; ## no critic (StringyEval)
  }
  use strict;
  $defn = "(?) $defn" if $defn && index $defn, '(';
  return ($fn,$defn||q(-));
}

sub bake_relationship {
  my( $pkg, $config, $ot, $mail_domain ) = @_;
  my @methods;
  use Data::Dumper qw(Dumper);
  ## use critic
my $Z = << 'XX';
warn "!pre!",Dumper( $config );
  return;
  my @methods = (
    create_method( $pkg, 'store', sprintf q(
    sub {
      my( $self, $params ) = @_;
      my $sql = 'insert ignore into %s ( %s ) values ( %s )';
      return $self->query( $sql, %s ) || $self->update( $params );
    }), ),
    create_method( $pkg, 'store', sprintf q(
    sub {
      my( $self, $params ) = @_;
      my $sql = 'update %s set %s where %s = ?';
      return $self->query( $sql, %s );
    ]), ),
    create_method( $pkg, 'data_columns', sub { return $data_columns; }),
  );

  ## Generate
  ##  * store & update methods...

  ##  * data_columns;
  ##  * get_XX
  ##  * get_XX_by_YY...
  ##  * get_all_XX
XX
  create_auto( $pkg, @methods );
  return;
}

## no critic (ExcessComplexity)
sub bake_adaptor {
  my( $pkg, $config, $ot, $mail_domain ) = @_;

  ## use critic
  my @methods;
  ( my $obj_pkg = $pkg ) =~ s{Pagesmith::Adaptor}{Pagesmith::Object}mxs;
  $root->dynamic_use( $obj_pkg );
  ## Main object properties
  my $type         = $config->{'type'};
  my $singular     = lc $config->{'type'};
  my $plural       = exists $config->{'plural'} ? $config->{'plural'} : $singular.'s';
  my $make_method  = "make_$singular";

  my $derived_tables;

## no critic (CommentedOutCode)
# Temporarily expunged!
#   ( my $t_pkg = $pkg ) =~ s{Adaptor}{Results};
#   create_method( $t_pkg, 'new', sub {
#     my ($class,$adap,$props ) = @_;
#     my $self = {
#       'conn'   => $adap->conn,
#       'cols'   => $props->{'cols'}||q(),
#       'tables' => $props->{'tables'}||q(),
#       'constr' => $props->{'constr'}||[],
#       'r_type' => 'multiple',
#       'limit'  => [],
#       'order'  => [],
#       'group' => [],
#     };
#     bless $self, $class;
#     return $self;
#   }, 'Creates a results object' );
#   create_method( $t_pkg, $make_method, sub {
#     my($self,$hashref,$partial)=@_;
#     return $obj_pkg->new( $self, $hashref, $partial );
#   });
#   create_method( $t_pkg, 'fetch', sub {
#     my $self = shift;
#     my $sql  = q();
#     my @pars = ();
#     my $rs = $self->conn->run( 'fixup' => sub { $_->selectall_arrayref( $sql, { 'Slice' => {} }, @pars ); } )||[];
#     my @res = map { $_ } @{$rs};
#     if( $self->{'r_type'} eq 'single' ) {
#       return unless @res;
#       return $self->$make_method( $res[0] );
#     }
#     return [ map { $self->$make_method( $_ ) } @{$_} ];
#   });
#
#   my $t = $t_pkg->new;
#      $t->fetch;
## use critic
  my @props        = @{$config->{'properties'}||[]};

  my ($uid_column,$uid_defn) =                pairfirst { 'uid'  eq (ref $b ? $b->{'type'} : $b )           } @props;
  my @columns                = pairmap { $a } pairgrep  { 'uid'  ne (ref $b ? $b->{'type'} : $b )           } @props;
  my @unique_columns         =                pairgrep  { ref $b && exists $b->{'unique'} && $b->{'unique'} } @props;
  my @enum_columns           =                pairgrep  { 'enum' eq (ref $b ? $b->{'type'} : $b )           } @props;

  foreach ( pairs @enum_columns) {
    my($k,$v) = @{$_};
    my $pl = exists $v->{'plural'} ? $v->{'plural'} : $k.'s';
#    warn ">> $_ -> $pl <<";
    push @methods, define_enum_adaptor( $pkg, $k, $pl, $v->{'values'} );
  }

  ## no critic (InterpolationOfMetachars)
  my @create_audit_columns;
  my @update_audit_columns;
  my $create_audit_functions = q();
  my $update_audit_functions = q();
  if( exists $config->{'audit'} ) { ## We need to add audit columns!!
    if( exists $config->{'audit'}{'user_id'} ) {
      if( $config->{'audit'}{'user_id'} ne 'update' ) {
        push @create_audit_columns, 'created_by_id';
        $create_audit_functions .= '$o->set_created_by_id( $self->user_id );';
      }
      if( $config->{'audit'}{'user_id'} ne 'create' ) {
        push @update_audit_columns, 'updated_by_id';
        $update_audit_functions .= '$o->set_updated_by_id( $self->user_id );';
        push @create_audit_columns, 'updated_by_id';
        $create_audit_functions .= '$o->set_updated_by_id( $self->user_id );';
      }
    }
    if( exists $config->{'audit'}{'user'} ) {
      if( $config->{'audit'}{'user'} ne 'update' ) {
        push @create_audit_columns, 'created_by';
        $create_audit_functions .= '$o->set_created_by( $self->user_name );';
      }
      if( $config->{'audit'}{'user'} ne 'create' ) {
        push @create_audit_columns, 'updated_by';
        $create_audit_functions .= '$o->set_updated_by( $self->user_name );';
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
        push @create_audit_columns, 'updated_at';
        $create_audit_functions .= '$o->set_updated_at( $self->now );';
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
        push @create_audit_columns, 'updated_ip';
        $create_audit_functions .= '$o->set_updated_ip( $self->user_ip );';
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
        push @create_audit_columns, 'updated_useragent';
        $create_audit_functions .= '$o->set_updated_useragent( $self->user_useragent );';
        push @update_audit_columns, 'updated_useragent';
        $update_audit_functions .= '$o->set_updated_useragent( $self->user_useragent );';
      }
    }
  }
  ## use critic
  my %c_related;
  foreach ( pairs @{$config->{'related'}} ) {
    my ($k,$conf) = @{$_};
    $c_related{$k}=$conf;
    if( exists $conf->{'to'} && exists $conf->{'derived'} ) {
      $derived_tables->{$k}{$_} = $conf->{'derived'}{$_} foreach keys %{$conf->{'derived'}};
    }
    if( exists $conf->{'to'} ) {
      ( my $sel_type = $k )=~s{_id\Z}{}mxs;
      push @methods, create_method( $pkg, 'fetch_'.$plural.'_by_'.$sel_type, sub {
        my ($self,$val) = @_;
        $val = $val->uid if ref $val;
        return [ map { $self->$make_method( $_ ) } @{$self->all_hash(
          'select '.$self->full_column_names.$self->audit_column_names.'
             from '.$self->select_tables.'
            where o.'.$k.' = ?
            order by o.'.$uid_column, $val )} ];
      }, qq((Obj|idx) Fetch all objects given related value/object linked by "$k") );
    }
  }

  my $full_column_names = join q(, ), map { "o.$_" } $uid_column, @columns;
  my $table_map = {};
  my $tid = 0;
  foreach my $key_column (sort keys %{$derived_tables} ) {

    unless( exists $c_related{$key_column}{'audit'} ) {
      $full_column_names  .= ", o.$key_column";
      push @columns, $key_column;
    }
    my $table_name = lc $c_related{$key_column}{'to'};
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

  if( exists $config->{'remove'} && $config->{'remove'} ) {
    my $delete_sql = sprintf "delete from $singular where $uid_column = ?";

    push @methods, create_method( $pkg, 'remove', sub {
      my( $self, $o ) = @_;
      my $o_id = ref $o ? $o->uid : $o;
      my $flag = $self->query( $delete_sql, $o_id );
      $o->clear_uid if ref $o && $flag;
      return $flag;
    });
  }

## no critic (InterpolationOfMetachars)
  my $store_perl = sprintf q(
sub {
  my( $self, $o ) = @_;
  %5$s
  return $o->set_%1$s_id( $self->insert( '
    insert into `%1$s`
           ( %2$s )
    values ( %3$s )',
    '%1$s', '%1$s_id',
    %4$s ) );
}), $singular,
    ( join qq(,\n           ), @columns, @create_audit_columns ),
    ( join q(,), map { q(?) }  @columns, @create_audit_columns ),
    ( join qq(,\n     ), map { sprintf '$o->get_%s', $_ } @columns, @create_audit_columns ),
    $create_audit_functions;
  my $update_perl = sprintf q(
sub {
  my( $self, $o ) = @_;
  %5$s
  return $self->query( '
    update `%1$s`
       set %2$s
     where %3$s = ?',
     %4$s,
    $o->uid );
}), $singular,
    ( join qq(,\n           ), map { $_.q( = ?) } @columns, @update_audit_columns ),
    $uid_column,
    ( join qq(,\n    ), map { sprintf '$o->get_%s', $_ } @columns, @update_audit_columns ),
    $update_audit_functions;
## use critic

  push @methods,

    create_method( $pkg, 'mail_domain', sub { return $mail_domain; }, '() Return mail domain - only used in scripts to conver userid to email address' ),
    ## Lightweight creator methods!
    create_method( $pkg, $make_method, sub {
      my($self,$hashref,$partial)=@_;
      return $obj_pkg->new( $self, $hashref, $partial );
    }, '(hashref) Bless a hash ref returned from SQL query into a '.$obj_pkg ),
    create_method( $pkg, 'create', sub {
      my $self = shift;
      return $self->$make_method({});
    }, '() Create an "empty object" of type '.$obj_pkg ),

    ## Fns to get column/table name lists out to allow other queries to get
    ## all object data!
    create_method( $pkg, 'full_column_names',   sub { return $full_column_names;  }, '() Returns an array of all the "columns" in the object' ),
    create_method( $pkg, 'audit_column_names',  sub { return $audit_column_names; }, '() Returns an array of all the "audit columns" in the object' ),
    create_method( $pkg, 'select_tables',       sub { return $select_tables;      }, '() Returns the tables requried to get all columns (inclding derived columns)' ),
    create_method( $pkg, 'store_obj',           $store_perl,                         '(Obj) Run SQL which stores object in database; on success updates the uid of the object' ),
    create_method( $pkg, 'update_obj',          $update_perl,                        '(Obj) Run SQL which updates given object in database' ),

    ## Writing content back to the database!

    create_method( $pkg, 'store', sub {
      my( $self, $o ) = @_;
      return if $o->is_partial;
      return $self->update_obj( $o ) if $o->uid;
      return $self->store_obj(  $o );
    }, '(Obj) Store object in database (either store/update) - skip if object is flagged as partial' ),

    ## Fetch all and fetch 1 methods....
    create_method( $pkg, 'fetch_all_'.$plural, sub {
      my $self = shift;
      return [ map { $self->$make_method( $_ ) } @{$self->all_hash(
        'select '.$self->full_column_names.$self->audit_column_names.'
           from '.$self->select_tables.'
           order by o.'.$uid_column )||[] } ];
    }, '() Fetches all objects of type '.$obj_pkg.' from database' ),
    create_method( $pkg, 'fetch_'.$singular, sub {
      my ( $self, $uid ) = @_;
      my $t = $self->row_hash(
          'select '.$self->full_column_names.$self->audit_column_names.'
             from '.$self->select_tables.'
            where o.'.$uid_column.' = ?', $uid );
      return $self->$make_method( $t ) if $t;
      return;
    }, '(val) Fetch objects of type '.$obj_pkg.' from database with given uid' ),
    ;
    foreach ( pairs @enum_columns) {
      my($enum_type,$v) = @{$_};
      push @methods, create_method( $pkg, 'fetch_'.$singular.'_by_'.$enum_type, sub {
        my ($self,$val) = @_;
        my $t = $self->row_hash(
          'select '.$self->full_column_names.$self->audit_column_names.'
             from '.$self->select_tables.'
            where o.'.$enum_type.' = ?', $val );
        return $self->$make_method( $t ) if $t;
        return;
      }, qq((val) Fetchs all objects of type $obj_pkg from database for given value of enum "$type") );
    }
    foreach ( pairs @unique_columns ) {
      my($colname,$defn) = @{$_};
      push @methods, create_method( $pkg, 'fetch_'.$singular.'_by_'.$colname, sub {
        my ($self,$val) = @_;
        my $t = $self->row_hash(
          'select '.$self->full_column_names.$self->audit_column_names.'
             from '.$self->select_tables.'
            where o.'.$colname.' = ?', $val );
        return $self->$make_method( $t ) if $t;
        return;
      }, qq((val) Fetch objects of type $obj_pkg from database with given unique value "$colname") ),
    }

## no critic (CommentedOutCode)
#    foreach ( ) {
#      push @methods, create_method( $pkg, 'fetch_'.$singular'.'_by_'.$type, sub {
#        my ($self,$val) = @_;
#        my $t = $self->row_hash(
#          'select '.$self->full_column_names.$self->audit_column_names.'
#             from '.$self->select_tables.'
#            where o.'.$type.' = ?', $val );
#        return $self->$make_method( $t ) if $t;
#        return;
#      } );
#
#    }
## use critic
  ## We need to add any additional auto generated methods that are required here!

  ## Finally update a method which returns all the updated methods...
  create_auto( $pkg, @methods );

  return;
}

sub create_auto {
  my( $pkg, @methods ) = @_;
  create_method( $pkg, 'auto_methods', sub {
    my @m = sort { $a->[0] cmp $b->[0] } pairs 'auto_methods', q(), 'dump_methods', q(), @methods;
    return @m;
  } );
  create_method( $pkg, 'dump_methods', sub {
    my @m = sort { $a->[0] cmp $b->[0] } pairs 'auto_methods', '() List methods and their definition', 'dump_methods', '() Dump methods and their definition', @methods;
    my $wr = Pagesmith::Utils::Wrap->new
                ->set_columns($LINE_WIDTH)
                ->set_headers(q(                                                     ),q(                                                     ));
    return sprintf "Package: $pkg\n\n%s\n", join q(),
      map { sprintf "%30s%-20s : %s\n", $_->[0], $_->[1], substr $wr->wrap( $_->[2] ), $LHS_WIDTH }
      map { $_->[1]=~m{[(]\s*(.*?)\s*[)]\s*(.*)}mxs
          ? [ $_->[0], $1 ? "( $1 )": q(( )), $2 ]
          : [ $_->[0], q(), $_->[1] ] }
        @m;
  } );
  return;
}

sub define_boolean {
  my( $pkg, $k, $default ) = @_;
  return (
    create_method( $pkg, q(is_).$k, sub {
      my $self = shift;
      return 'yes' eq ($self->{'obj'}{$k}||$default);
    }, qq(() returns true if the boolean value for "$k" is true ("yes")) ),
    create_method( $pkg, q(off_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 'no';
      return $self;
    }, qq(() Sets the boolean value for "$k" to false ("yes")) ),
    create_method( $pkg, q(on_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 'yes';
      return $self;
    }, qq(() Sets the boolean value for "$k" is true ("yes")) ),
    create_method(  $pkg, q(set_).$k, sub {
      my( $self, $value ) = @_;
      $value = lc $value;
      if( 'yes' eq $value || 'no' eq $value ) {
        $self->{'obj'}{$k} = $value;
      } else {
        warn "Value for $k is incorrect ($value)\n";
      }
      return $self;
    }, qq((val) Sets the boolean value for "$k" to true (val="yes") or false (val="no") or warns) ),
  );
}

sub define_enum {
  my( $pkg, $k, $pl, $default, $values ) = @_;
  my $values_hash = 'HASH' eq ref $values
                  ? $values
                  : { 'HASH'  eq ref $values->[0] ? map { $_->{'value'} => $_->{'name'} } @{$values}
                    : 'ARRAY' eq ref $values->[0] ? map { $_->[0]       => $_->[1]      } @{$values}
                    :                               map { $_            => $_           } @{$values}
                    };
  my $values_ordered =  'ARRAY' eq ref $values
    ? (
        'HASH'  eq ref $values->[0] ? [ map {$_->{'value'}} @{$values} ]
      : 'ARRAY' eq ref $values->[0] ? [ map {$_->[0]}       @{$values} ]
      :                               $values,
    )
    : [sort { $values->{$a} cmp $values->{$b} } %{$values} ];
  my $ordered_hash = [ map { [ $_ => $values_hash->{$_} ] } @{$values_ordered} ];
  my $ordered_hr   = [ map { $values_hash->{$_} } @{$values_ordered} ];

  return (
    create_method( $pkg, q(is_).$k, sub {
      my ( $self, $val ) = @_;
      return $val eq ($self->{'obj'}{$k}||$default)||q();
    }, qq((val) Check to see if field "$k" has given value)),
    create_method( $pkg, q(set_).$k, sub {
      my( $self, $value ) = @_;
      if( exists $values_hash->{$value} ) {
        $self->{'obj'}{$k} = $value;
      } else {
        warn "Value for $k is incorrect ($value)\n";
      }
      return $self;
    }, qq(() Get value of enumerated field "$k")),
    create_method( $pkg, q(get_).$k.q(_hr), sub {
      my $self = shift;
      return $values_hash->{$self->{'obj'}{$k}||$default};
    }, qq(() Get human readable version of enumerated field "$k")),
    create_method( $pkg, q(all_).$pl.q(_hr), sub {
      return $ordered_hr;
    }, qq(() Return an arrayref of hr version of enumerated field "$k") ),
    create_method( $pkg, q(all_).$pl.q(_sorted), sub {
      return $ordered_hash;
    }, qq(() Return an arrayref of arrayrefs of enumerated field "$k"values [[value, hr value]]) ),
    create_method( $pkg, $k.q(_hr), sub {
      return map { exists $values_hash->{$_} ? $values_hash->{$_} : () } @_;
    }, qq((val+) Return the human readable form of the enumerated field "$k") ),
  );
}

sub define_enum_adaptor {
  my( $pkg, $k, $pl, $values ) = @_;
  my $values_hash = 'HASH' eq ref $values
                  ? $values
                  : { 'HASH'  eq ref $values->[0] ? map { $_->{'value'} => $_->{'name'} } @{$values}
                    : 'ARRAY' eq ref $values->[0] ? map { $_->[0]       => $_->[1]      } @{$values}
                    :                               map { $_            => $_           } @{$values}
                    };
  my $values_ordered =  'ARRAY' eq ref $values
    ? (
        'HASH'  eq ref $values->[0] ? [ map {$_->{'value'}} @{$values} ]
      : 'ARRAY' eq ref $values->[0] ? [ map {$_->[0]}       @{$values} ]
      :                               $values,
    )
    : [sort { $values->{$a} cmp $values->{$b} } %{$values} ];
  my $ordered_hash = [ map { [ $_ => $values_hash->{$_} ] } @{$values_ordered} ];
  my $ordered_hr   = [ map { $values_hash->{$_} } @{$values_ordered} ];

  return (
    create_method( $pkg, q(all_).$pl.q(_hr), sub {
      return $ordered_hr;
    }, qq(() Return an arrayref of hr version of enumerated field "$k") ),
    create_method( $pkg, q(all_).$pl.q(_sorted), sub {
      return $ordered_hash;
    }, qq(() Return an arrayref of arrayrefs of enumerated field "$k"values [[value, hr value]]) ),
    create_method( $pkg, $k.q(_hr), sub {
      return map { exists $values_hash->{$_} ? $values_hash->{$_} : () } @_;
    }, qq((val) Return the human readable form of the enumerated field "$k") ),
  );
}

sub define_index {
  my( $pkg, $k ) = @_;
  return (
    create_method( $pkg, q(set_).$k, sub {
      my ( $self, $value ) = @_;
      if( $value <= 0 ) {
        warn "Trying to set non positive value for '$k'\n";
      } else {
        $self->{'obj'}{$k} = $value;
      }
      return $self;
    }, qq((val) Set value of id key "$k", warn if value being set <=0) ),
    create_method( $pkg, q(clear_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 0;
      return $self;
    }, qq(() Clear id key "$k") ),
  );
}

sub define_set {
  my( $pkg, $k ) = @_;
  return create_method( $pkg, q(set_).$k, sub {
    my($self,$value) = @_;
    $self->{'obj'}{$k} = $value;
    return $self;
  }, qq((val) Set value of property "$k") );
}

sub define_get {
  my( $pkg, $k, $default ) = @_;
  return create_method( $pkg, q(get_).$k, sub {
    my $self = shift;
    return defined $self->{'obj'}{$k} ? $self->{'obj'}{$k} : $default;
  }, qq(() Get value of property "$k") );
}

sub define_uid {
  my( $pkg, $k ) = @_;
  return (
    create_method( $pkg, q(uid), sub {
      my $self = shift;
      return $self->{'obj'}{$k};
    }, qq(() Get value of unique id field "$k") ),
    create_method( $pkg, 'clear_uid', sub {
      my $self = shift;
      $self->{'obj'}{$k} = 0;
      return $self;
    }, qq(() Clear value of unique id field "$k") ),
  );
}

sub define_related_get_set {
  my( $pkg, $type, $k, $derived ) = @_;
  my $fetch_method = 'fetch_'.lc $type;
  my $get_method   = 'get_'.$k;
  (my $obj_key = $k) =~ s{_id\Z}{}mxsg;
  ## Object/get setters!
  ## no critic (InterpolationOfMetachars)
  my $set_perl = sprintf q(sub {
      my ( $self, $%1$s ) = @_;
      $%1$s = $self->get_other_adaptor( '%2$s' )->%3$s( $%1$s ) unless ref $%1$s;
      if( $%1$s ) {
        $self->{'obj'}{'%4$s'} = $%1$s->uid;%5$s
      }
      return $self;
    }),
      $obj_key, $type, $fetch_method, $k,
      join q(),
      map { sprintf "\n".q(    $self->{'obj'}{'%s'} = $%s->get_%s;), $derived->{$_}, $obj_key, $_ }
      keys %{$derived};

  return (
    create_method( $pkg, 'get_'.$obj_key, sub {
      my $self = shift;
      return $self->get_other_adaptor( $type )->$fetch_method( $self->$get_method );
    }, qq(() fetch related objects of type "$type" given "$k") ),
    create_method( $pkg, 'set_'.$obj_key, $set_perl, qq((Obj) Set related object of type "$type" associated with object via "$k") ),
  );
  ## use critic
}

sub define_related_get_all {
  my( $pkg, $type, $k, $my_type ) = @_;
  my $method = sprintf 'fetch_%s_by_%s', $k, lc $my_type;
  return create_method( $pkg, q(fetch_all_).$k, sub {
    my $self = shift;
    return $self->get_other_adaptor( $type )->$method( $self );
  }, qq(() Fetch objects of type "$type" related to self via index "$k") );
}

sub define_related_get_rel {
  my( $pkg, $k, $my_type ) = @_;
  my $method = sprintf 'get_%s_by_%s', lc $k, lc $my_type;
  return create_method( $pkg, 'get_'.lc $k, sub {
    my $self = shift;
    return $self->get_other_adaptor( $k )->$method( $self );
  }, qq(() Get related values of type "$k") );
}

sub bake_object {
  my( $pkg, $config, $ot ) = @_;

  my @methods;
  ## Main object properties
  if( exists $config->{'remove'} && $config->{'remove'} ) {
    push @methods, create_method( $pkg, 'remove', sub { my $self = shift; return $self->adaptor->remove( $self ); } );
  }
  foreach( pairs @{$config->{'properties'}} ) {
    my($k,$defn) = @{$_};
       $defn     = { 'type' => $defn } unless ref $defn;
    my $type     = $defn->{'type'};
    my $default  = exists $defn->{'default'} ? $defn->{'default'}
                 : exists $DEFAULTS->{$type} ? $DEFAULTS->{$type}
                 :                             undef
                 ;

    push @methods, define_get( $pkg, $k, $default );          ## General Get method...
    push @methods, define_uid( $pkg, $k )  if $type eq 'uid'; ## unique ID property!;

    for( $type ) {                             ## Methods for different object types...
      when( $_ eq 'boolean' )           { push @methods, define_boolean(  $pkg, $k, $default ); }
      when( $_ eq 'enum'    )           {
        my $pl = exists $defn->{'plural'} ? $defn->{'plural'} : $k.'s';
#        warn ">> $k -> $pl <<";
        push @methods, define_enum(     $pkg, $k, $pl, $default, $defn->{'values'} );
      }
      when( $_ eq 'id' || $_ eq 'uid' ) { push @methods, define_index(    $pkg, $k ); }
      default                           { push @methods, define_set(      $pkg, $k ); }
    }
  }

  ## Now we need to look at the relationships between objects...
  foreach( pairs @{$config->{'related'}} ) {
    my($k,$defn) = @{$_};
    if( exists $defn->{'to'} ) {        ## object has a single related object!
      push @methods, define_get(   $pkg, $k );
      push @methods, define_index( $pkg, $k );
      my %derived;
      ## derived get_calls!
      if( exists $defn->{'derived'} ) {
        %derived = %{$defn->{'derived'}};
        push @methods, define_get( $pkg, $_ ) foreach values %derived;
      }
      push @methods, define_related_get_set( $pkg, $defn->{'to'}, $k, \%derived );
    } elsif( exists $defn->{'from'} ) { ## object has multiple related objects...
      ## This is a many-1 relationship
      push @methods, define_related_get_all( $pkg, $defn->{'from'}, $k, $config->{'type'} );
    } else {                            ## This is a "relationship" with added attributes!
      push @methods, define_related_get_rel( $pkg, $k, $config->{'type'} );
    }
  }
  create_auto( $pkg, @methods );
  return;
}

## Functions that munge the object configuration structure
## Merge in relationships!

sub parse_defn {
  my ( $defn, $type ) = @_;
  if( exists $defn->{'relationships'}{$type} ) {
    return { 'type' => 'relationship', 'objects' => $defn->{'relationships'}{$type}{'objects'}, 'additional' => $defn->{'relationships'}{$type}{'additional'} };
  }
  my $d = $defn->{'objects'}{$type};
  #use Data::Dumper; print Dumper( $d );
  my $definition = {
    'type'           => $type,
    'properties'     => $d->{'properties'},
    'related'        => [],
  };

  foreach (qw(properties plural audit remove)) {
    $definition->{$_} = $d->{$_} if exists $d->{$_};
  }

  if( exists $d->{'related'} ) {
    push @{$definition->{'related'}}, @{$d->{'related'}};
  }

  if( exists $defn->{'relationships'} ) {
    push @{$definition->{'related'}}, $_, $defn->{'relationships'}{$_}
      foreach grep { exists $defn->{'relationships'}{$_}{'objects'}{$type} }
              keys %{$defn->{'relationships'}};
  }

  return $definition;
}

## This is the really nasty function which squirts methods into the
## Support namespace to define the methods in the Object/Adaptor
## classes...

sub bake_model {
##@param (string) package name
##@param (hashref) defn of objects of relationships
##
## Pushes four methods:
##
## * type_defn       - returns defn for object used in Object/Adaptor code
## * my_rels       - returns defn for relationship used in Adaptor code?
## * my_obj_types  - returns list of Object types
## * my_rel_types  - returns list of Relationship types

  my( $pkg, $DEFN ) = @_;
  my $mail_domain = exists $DEFN->{'mail_domain'} ? $DEFN->{'mail_domain'} : q(-);
  my @methods = (
    create_method( $pkg, 'mail_domain', sub { return $mail_domain; }, '() Return mail domain - only used in scripts to conver userid to email address' ),
    create_method( $pkg, 'my_obj_types', sub {
      return unless exists $DEFN->{'objects'};
      my @m = sort keys %{$DEFN->{'objects'}};
      return @m;
    } , '() Return list of object types in model' ),
    create_method( $pkg, 'my_rel_types', sub {
      return unless exists $DEFN->{'relationships'};
      my @m = sort keys %{$DEFN->{'relationships'}};
      return @m;
    } , '() Return list of relationship types in model' ),
    create_method( $pkg, 'full_defn', sub {
      return $DEFN;
    } , '() Return full definition of model' ),
    create_method( $pkg, 'type_defn', sub {
      my $type = shift;
      return parse_defn( $DEFN, $type );
    }, '(type) Return definition of Object/relationship of given type)' ),
  );
  create_auto( $pkg, @methods );
  return 1;
}

sub bake_support {
##@param (string) package name
  my $pkg = shift;
  (my $ns = $pkg) =~ s{Pagesmith::Support::}{}mxs;
  $root->dynamic_use( 'Pagesmith::Model::'.$ns );
  my $mail_method = 'Pagesmith::Model::'.$ns.'::mail_domain';
  no strict 'refs'; ## no critic (NoStrict)
  my $mail_domain = &{$mail_method}( );
  use strict;
  my @methods = (
    create_method( $pkg, 'mail_domain', sub { return $mail_domain; }, '() Return mail domain - only used in scripts to conver userid to email address' ),
    create_method( $pkg, 'base_class', sub { return $ns; }, '() Return the base class of objects defined in model' ),
  );
  create_auto( $pkg, @methods );
  return 1;
}

sub bake_base_adaptor {
  my $pkg = caller 0;
  my $mail_domain = q();
  ( my $ns  = $pkg ) =~ s{Pagesmith::Adaptor::}{}mxs;
  $root->dynamic_use( 'Pagesmith::Model::'.$ns );
  my $meth         = 'Pagesmith::Model::'.$ns.'::mail_domain';
  no strict 'refs';  ## no critic (NoStrict)
  $mail_domain    = &{$meth}();
  use strict;
  (my $db_key = lc $ns) =~ s{::}{_}mxsg;
  my @methods = (
    create_method( $pkg, 'base_class',      sub { return $ns;          }, '() Return the base class of objects defined in model' ),
    create_method( $pkg, 'mail_domain',     sub { return $mail_domain; }, '() Return mail domain - only used in scripts to conver userid to email address' ),
    create_method( $pkg, 'connection_pars', sub { return $db_key;      }, '() Return the connection keys - by default it is the base_class with :: -> _ & all lower case' ),
  );
  create_auto( $pkg, @methods );
  return;
}

1;
