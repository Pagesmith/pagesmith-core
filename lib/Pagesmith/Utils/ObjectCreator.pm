package Pagesmith::Utils::ObjectCreator;

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

our @EXPORT_OK = qw(
  bake_adaptor
  bake_relationship
  bake_object
  bake_model
  bake_base_adaptor
);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

const my $DEFAULTS => {
  'number'  => 0,
  'boolean' => 'no',
};

my $root = Pagesmith::Root->new;

## This will need our standard get other adaptor method call!

## Functions to define accessors for objects....

sub create_method {
  my ( $pkg, $fn, $sub, $flag ) = @_;
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
  return $fn;
}

sub bake_relationship {
  my( $config ) = @_;
  my $pkg = caller 0;
  ## no critic (NoStrict)
  if( ! defined $config ) {
    my ( $ns, $ot ) = $pkg =~ m{(.*)::(.*)}mxs;
    $ns =~ s{\APagesmith::Adaptor}{Pagesmith::Support}mxs;
    $ns.='::my_defn';
    no strict 'refs';
    $config = &{$ns}( $ot );
    use strict;
  } elsif( ! ref $config ) {
    my $ot = $config;
    (my $ns = substr $pkg, 0, - length $ot) =~ s{\APagesmith::Adaptor}{Pagesmith::Support}mxs;
    $ns .='my_defn';
    no strict 'refs';
    $config = &{$ns}( $ot );
    use strict;
  }
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
  return;
}

sub bake_base_adaptor {
  my $pkg = caller 0;
  my $mail_domain = q();

  ( my $ns  = $pkg ) =~ s{Pagesmith::Adaptor::}{}mxs;
  my $meth         = 'Pagesmith::Support::'.$ns.'::mail_domain';
  no strict 'refs';  ## no critic (NoStrict)
  $mail_domain    = &{$meth}();
  use strict;
  (my $db_key = lc $ns) =~ s{::}{_}mxsg;
  my @methods = (
    create_method( $pkg, 'base_class',      sub { return $ns; } ),
    create_method( $pkg, 'mail_domain',     sub { return $mail_domain; } ),
    create_method( $pkg, 'connection_pars', sub { return $db_key; } ),
  );
  create_method( $pkg, 'auto_methods', sub { my @m = sort 'auto_methods', @methods; return @m; });
  return;
}

## no critic (ExcessComplexity)
sub bake_adaptor {
  my( $config, $mail_domain ) = @_;
  my $pkg = caller 0;
  ## no critic (NoStrict)
  if( ! defined $config ) {
    my ( $ns, $ot ) = $pkg =~ m{(.*)::(.*)}mxs;
    $ns =~ s{\APagesmith::Adaptor}{Pagesmith::Support}mxs;
    my $meth      = $ns.'::my_defn';
    no strict 'refs';
    $config       = &{$meth}( $ot );
    $meth         = $ns.'::mail_domain';
    $mail_domain  = &{$meth}( );
    use strict;
  } elsif( ! ref $config ) {
    my $ot = $config;
    (my $ns = substr $pkg, 0, - length $ot) =~ s{\APagesmith::Adaptor}{Pagesmith::Support}mxs;
    my $meth      = $ns.'::my_defn';
    no strict 'refs';
    $config       = &{$meth}( $ot );
    use strict;
    $meth         = $ns.'::mail_domain';
    no strict 'refs';
    $mail_domain  = &{$meth}( );
    use strict;
  }

  ## use critic

  my @methods;
  ( my $obj_pkg = $pkg ) =~ s{Pagesmith::Adaptor}{Pagesmith::Object}mxs;
  $root->dynamic_use( $obj_pkg );
  ## Main object properties
  my $type         = $config->{'type'};
  my $singular     = lc $config->{'type'};
  my $plural       = exists $config->{'plural'} ? $config->{'plural'} : $singular.'s';
  my $props        = $config->{'properties'};
  my $make_method  = "make_$singular";

  my $derived_tables;
  my @create_audit_columns;
  my @update_audit_columns;
  my $create_audit_functions = q();
  my $update_audit_functions = q();
  my ($uid_column) = grep { 'uid' eq (ref $props->{$_} ? $props->{$_}{'type'} : $props->{$_} ) } keys %{$props};
  my @columns        = grep { 'uid' ne (ref $props->{$_} ? $props->{$_}{'type'} : $props->{$_} ) } keys %{$props};
  my @unique_columns = grep { ref $props->{$_} && exists $props->{$_}{'unique'} && $props->{$_}{'unique'} } keys %{$props};
  my @enum_columns   = grep { 'enum' eq (ref $props->{$_} ? $props->{$_}{'type'} : $props->{$_} ) } keys %{$props};
  foreach (@enum_columns) {
    my $pl = exists $props->{$_}{'plural'} ? $props->{$_}{'plural'} : $_.'s';
#    warn ">> $_ -> $pl <<";
    push @methods, define_enum_adaptor( $pkg, $_, $pl, $props->{$_}{'values'} );
  }
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
        } );
      }
    }
  }
  my $full_column_names = join q(, ), map { "o.$_" } $uid_column, @columns;
  my $table_map = {};
  my $tid = 0;
  foreach my $key_column (sort keys %{$derived_tables} ) {
    unless( exists $config->{'related'}{$key_column}{'audit'} ) {
      $full_column_names  .= ", o.$key_column";
      push @columns, $key_column;
    }
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

  push @methods,

    ## Light weight creator methods!

    create_method( $pkg, 'mail_domain', sub { return $mail_domain; } ),
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
    insert into `%1$s`
           ( %2$s )
    values ( %3$s )',
    '%1$s', '%1$s_id',
    %4$s ) );
}), $singular,
      ( join qq(,\n           ), @columns, @create_audit_columns ),
      ( join q(,), map { q(?) } @columns, @create_audit_columns ),
      ( join qq(,\n     ), map { sprintf '$o->get_%s', $_ } @columns, @create_audit_columns ),
      $create_audit_functions,
    ),
    create_method( $pkg, 'update_obj', sprintf q(
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
    foreach my $type (@unique_columns) {
      push @methods, create_method( $pkg, 'fetch_'.$singular.'_by_'.$type, sub {
        my ($self,$val) = @_;
        my $t = $self->row_hash(
          'select '.$self->full_column_names.$self->audit_column_names.'
             from '.$self->select_tables.'
            where o.'.$type.' = ?', $val );
        return $self->$make_method( $t ) if $t;
        return;
      } );
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
  create_method( $pkg, 'auto_methods', sub { my @m = sort 'auto_methods', @methods; return @m; });

  return;
}

sub define_boolean {
  my( $pkg, $k, $default ) = @_;
  return (
    create_method( $pkg, q(is_).$k, sub {
      my $self = shift;
      return 'yes' eq ($self->{'obj'}{$k}||$default);
    } ),
    create_method( $pkg, q(off_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 'no';
      return $self;
    } ),
    create_method( $pkg, q(on_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 'yes';
      return $self;
    } ),
    create_method(  $pkg, q(set_).$k, sub {
      my( $self, $value ) = @_;
      $value = lc $value;
      if( 'yes' eq $value || 'no' eq $value ) {
        $self->{'obj'}{$k} = $value;
      } else {
        warn "Value for $k is incorrect ($value)\n";
      }
      return $self;
    } ),
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
    } ),
    create_method( $pkg, q(set_).$k, sub {
      my( $self, $value ) = @_;
      if( exists $values_hash->{$value} ) {
        $self->{'obj'}{$k} = $value;
      } else {
        warn "Value for $k is incorrect ($value)\n";
      }
      return $self;
    } ),
    create_method( $pkg, q(get_).$k.q(_hr), sub {
      my $self = shift;
      return $values_hash->{$self->{'obj'}{$k}||$default};
    } ),
    create_method( $pkg, q(all_).$pl.q(_hr), sub {
      return $ordered_hr;
    } ),
    create_method( $pkg, q(all_).$pl.q(_sorted), sub {
      return $ordered_hash;
    } ),
    create_method( $pkg, $k.q(_hr), sub {
      return map { exists $values_hash->{$_} ? $values_hash->{$_} : () } @_;
    } ),
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
    } ),
    create_method( $pkg, q(all_).$pl.q(_sorted), sub {
      return $ordered_hash;
    } ),
    create_method( $pkg, $k.q(_hr), sub {
      return map { exists $values_hash->{$_} ? $values_hash->{$_} : () } @_;
    } ),
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
    } ),
    create_method( $pkg, q(clear_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 0;
      return $self;
    } ),
  );
}

sub define_set {
  my( $pkg, $k ) = @_;
  return create_method( $pkg, q(set_).$k, sub {
    my($self,$value) = @_;
    $self->{'obj'}{$k} = $value;
    return $self;
  } );
}

sub define_get {
  my( $pkg, $k, $default ) = @_;
  return create_method( $pkg, q(get_).$k, sub {
    my $self = shift;
    return defined $self->{'obj'}{$k} ? $self->{'obj'}{$k} : $default;
  } );
}

sub define_uid {
  my( $pkg, $k ) = @_;
  return (
    create_method( $pkg, q(uid), sub {
      my $self = shift;
      return $self->{'obj'}{$k};
    } ),
    create_method( $pkg, 'clear_uid', sub {
      my $self = shift;
      $self->{'obj'}{$k} = 0;
      return $self;
    } ),
  );
}

sub define_related_get_set {
  my( $pkg, $type, $k, $derived ) = @_;
  my $fetch_method = 'fetch_'.lc $type;
  my $get_method   = 'get_'.$k;
  (my $obj_key = $k) =~ s{_id\Z}{}mxsg;
  ## Object/get setters!
  ## no critic (InterpolationOfMetachars)
  return (
    create_method( $pkg, 'get_'.$obj_key, sub {
      my $self = shift;
      return $self->get_other_adaptor( $type )->$fetch_method( $self->$get_method );
    } ),
    create_method(
      $pkg, 'set_'.$obj_key, sprintf q(sub {
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
      keys %{$derived},
    ),
  );
  ## use critic
}

sub define_related_get_all {
  my( $pkg, $type, $k, $my_type ) = @_;
  my $method = sprintf 'fetch_%s_by_%s', $k, lc $my_type;
  return create_method( $pkg, q(fetch_all_).$k, sub {
    my $self = shift;
    return $self->get_other_adaptor( $type )->$method( $self );
  } );
}

sub define_related_get_rel {
  my( $pkg, $k, $my_type ) = @_;
  my $method = sprintf 'get_%s_by_%s', lc $k, lc $my_type;
  return create_method( $pkg, 'get_'.lc $k, sub {
    my $self = shift;
    return $self->get_other_adaptor( $k )->$method( $self );
  } );
}

sub bake_object {
  my( $config ) = @_;
  my $pkg = caller 0;

  ## no critic (NoStrict)
  if( ! defined $config ) {
    my ( $ns, $ot ) = $pkg =~ m{(.*)::(.*)}mxs;
    $ns =~ s{\APagesmith::Object}{Pagesmith::Support}mxs;
    $ns.='::my_defn';
    no strict 'refs';
    $config = &{$ns}( $ot );
    use strict;
  } elsif( ! ref $config ) {
    my $ot = $config;
    (my $ns = substr $pkg,0,- length $ot) =~ s{\APagesmith::Object}{Pagesmith::Support}mxs;
    $ns .='my_defn';
    no strict 'refs';
    $config = &{$ns}( $ot );
    use strict;
  }
  ## use critic
  my @methods;
  ## Main object properties
  if( exists $config->{'remove'} && $config->{'remove'} ) {
    push @methods, create_method( $pkg, 'remove', sub { my $self = shift; return $self->adaptor->remove( $self ); } );
  }
  foreach my $k ( keys %{$config->{'properties'}} ) {
    my $defn     = $config->{'properties'}{$k};
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
  foreach my $k ( keys %{$config->{'related'}} ) {
    my $defn = $config->{'related'}{$k};
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
  create_method( $pkg, 'auto_methods', sub { my @m = sort 'auto_methods', @methods; return @m; });
  return;
}

## Functions that munge the object configuration structure
## Merge in relationships!

sub parse_defn {
  my ( $defn, $type ) = @_;
  if( exists $defn->{'relationships'}{$type} ) {
    return $defn->{'relationships'}{$type};
  }
  my $d = $defn->{'objects'}{$type};
  my $definition = {
    'type'           => $type,
    'properties'     => $d->{'properties'},
    'related'        => {},
  };

  foreach (qw(properties plural audit remove)) {
    $definition->{$_} = $d->{$_} if exists $d->{$_};
  }

  if( exists $d->{'related'} ) {
    $definition->{'related'}{$_} = $d->{'related'}{$_} foreach keys %{$d->{'related'}};
  }

  if( exists $defn->{'relationships'} ) {
    $definition->{'related'}{$_} = $defn->{'relationships'}{$_} foreach
      grep { exists $defn->{'relationships'}{$_}{'objects'}{$type} }
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
## * my_defn       - returns defn for object used in Object/Adaptor code
## * my_rels       - returns defn for relationship used in Adaptor code?
## * my_obj_types  - returns list of Object types
## * my_rel_types  - returns list of Relationship types

  my $DEFN = shift;
  my $pkg = caller 0;
  (my $ns = $pkg) =~ s{Pagesmith::Support::}{}mxs;
  my $mail_domain = exists $DEFN->{'mail_domain'} ? $DEFN->{'mail_domain'} : q(-);
  my @methods = (
    create_method( $pkg, 'mail_domain', sub { return $mail_domain; } ),
    create_method( $pkg, 'base_class', sub { return $ns; } ),
    create_method( $pkg, 'my_obj_types', sub {
      return unless exists $DEFN->{'objects'};
      my @m = sort keys %{$DEFN->{'objects'}};
      return @m;
    } ),
    create_method( $pkg, 'my_rel_types', sub {
      return unless exists $DEFN->{'relationships'};
      my @m = sort keys %{$DEFN->{'relationships'}};
      return @m;
    } ),
    create_method( $pkg, 'full_defn', sub {
      return $DEFN;
    } ),
    create_method( $pkg, 'my_defn', sub {
      my $type = shift;
      return parse_defn( $DEFN, $type );
    } ),
  );
  create_method( $pkg, 'auto_methods', sub { my @m = sort 'auto_methods', @methods; return @m; });
  return;
}

1;
