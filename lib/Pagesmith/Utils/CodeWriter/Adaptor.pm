package Pagesmith::Utils::CodeWriter::Adaptor;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

## Package to write packages etc!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Mon, 11 Feb 2013
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Utils::CodeWriter);
use Text::Wrap qw(wrap);

sub base_class {
  my $self = shift;
  my $filename = sprintf '%s/Adaptor%s.pm',$self->base_path,$self->ns_path;
  my @secure_types = grep { $self->conf('objects',$_,'user_restriction') } $self->objecttypes;
  my $secure_methods = q();
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  $secure_methods .= '
## Security constraint methods for "non-secured" sites
## Secure methods are in the Secure version of the adaptors
';
  foreach( @secure_types ) {
    $secure_methods .= sprintf q(
sub %1$s_constraint {
  my $self = shift;
  return (q(),q());
}
), $_;
  }

  my $user_details_code = q();
  my $user_perm_code    = q();
  my $user_table       = $self->conf( 'users', 'table' );
  if( $user_table ) {
    my $user_id_name = $self->id($user_table);
    my $permissions = $self->conf( 'users', 'permissions' );

    $user_details_code .= sprintf q(
  my $user_details = $self->row_hash( 'select %2$s, %3$s from %1$s where username = ?',
    $self->{'username'} );),
      $user_table, $user_id_name, join q(, ), @{$permissions};

    if( $self->conf( 'users', 'auto_vivify' ) ) {
      $user_details_code .= sprintf q(
  if( !$user_details ) {
    my $user_id = $self->insert( 'insert ignore into %1$s (username) values(?)', '%1$s', '%2$s', $self->{'username'} );
    $user_details = { 'user_id' => $user_id };
  }), $user_table, $user_id_name;
    }
    $user_details_code .= q(
  $self->{'_user_id'} = $user_details->{'user_id'};);

    foreach ( @{$permissions} ) {
      $user_details_code .= sprintf q(
  $self->{'_%1$s'} = exists $user_details->{'%1$s'} && $user_details->{'%1$s'} eq 'Yes' ? 1: 0;), $_;
      $user_perm_code .= sprintf q(
sub user_is_%1$s {
  my $self = shift;
  return $self->{'_%1$s'};
}
), $_;
    }
  }

  my $perl = sprintf q(package Pagesmith::Adaptor::%1$s;

## Base adaptor for objects in %1$s namespace
%2$s
use base qw(Pagesmith::Adaptor);
use Pagesmith::Core qw(user_info);

sub connection_pars {
#@params (self)
#@return (string)
## Returns key to database connection in configuration file

  my $self = shift;
  return q(%3$s);
}

sub attach_script_user {
  my $self = shift;
  my $user_info = user_info();
  return $self->attach_user( {
    'username' => $user_info->{'username'},
    'name'     => $user_info->{'name'},
    'type'     => 'system',
  });
}

sub attach_user {
#@params (self) (string{} properties)
#@return (self)
## Attach user for security/audit purposes...
  my( $self, $hashref ) = @_;
  $self->{'_username'} = $hashref->{'username'};
  $self->{'_name'    } = $hashref->{'name'};
  $self->{'_usertype'} = $hashref->{'type'};
## Now we get permissions....%4$s
  return $self;
}
%5$s

sub user {
#@params (self)
#@return (string)
## Returns key to database connection in configuration file

  my $self = shift;
  return $self->{'_user'};
}

sub get_other_adaptor {
#@params (self) (string object type)
#@return (Pagesmith::Adaptor::%1$s)
## Returns a database adaptor for the given type of object.

  my( $self, $type ) = @_;
  ## Get the adaptor from the "pool of adaptors"
  ## If the adaptor doesn't exist then we well get it, and create
  ## attach it to the pool

  my $adaptor = $self->get_adaptor_from_pool( $type );
  return $adaptor || $self->get_adaptor(      "%1$s::$type", $self )
                          ->attach_user( $self->user )
                          ->add_self_to_pool( $type );
}

1;

__END__

),
    $self->namespace,    ## %1$s
    $self->boilerplate,  ## %2$s
    $self->ns_key,       ## %3$s
    $user_details_code,  ## %4$s
    $user_perm_code,     ## %5$s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

sub secure_classes {
  my $self = shift;

  my @secure_types = grep { $self->conf('objects',$_,'user_restriction') } $self->objecttypes;
  return unless @secure_types;

  my @constraint_methods;
  my @out_files;
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $audit_user  = $self->conf( 'audit_user' ) || q(id);

  my $user_ky     = $audit_user eq 'id' ? 'user_id' : 'user';

  foreach my $type ( @secure_types ) {
    my $filename = sprintf '%s/Adaptor%s/%s/Secure.pm',
      $self->base_path,$self->ns_path,$self->fp($type);

    my $perl = sprintf q(package Pagesmith::Adaptor::%1$s::%2$s::Secure;
## Secure adaptor (adds constraint functionality) for %2$s objects in %1$s namespace
%3$s

use base qw(Pagesmith::Adaptor::%1$s::Secure Pagesmith::Adaptor::%1$s::%2$s);

1;

__END__
),
      $self->namespace,    ## %1$s
      $type,               ## %2$s
      $self->boilerplate,  ## %3$s
    ;
    push @out_files, $self->write_file( $filename, $perl );

    my $conf       = $self->conf('objects',$type);
    my $type_ky    = $self->ky( $type );
    my $alias_name = exists $conf->{'aliasname'} ? $conf->{'aliasname'} : 'o';
    my $table_name = exists $conf->{'user_restriction'}{'table'} ? $conf->{'user_restriction'}{'table'} : 'user_'.lc $type;

    push @constraint_methods, sprintf q(
sub %1$s_constraint {
  my $self = shift;
  return (
    ', %2$s constr',                                         ## From
    ' and %3$s.%4$s = constr.%4$s and constr.%5$s = ?',      ## Where
    $self->user,                                             ## Extra parameter!
  );
}

),
      lc $type,     ## %1$s
      $table_name,  ## %2$s
      $alias_name,  ## %3$s
      $type_ky,     ## %4$s
      $user_ky,     ## %5$s
    ;
  }

  my $filename = sprintf '%s/Adaptor%s/%s.pm',$self->base_path,$self->ns_path,'Secure';
  my $perl = sprintf q(package Pagesmith::Adaptor::%1$s::Secure;
## Secure Base adaptor (adds constraint functionality) for objects in %1$s namespace
%2$s

%3$s

1;

__END__
),
    $self->namespace,
    $self->boilerplate,
    join q(), @constraint_methods
  ;
#@endraw
## use critic
  push @out_files, $self->write_file( $filename, $perl );
  return @out_files;
}

## no critic (ExcessComplexity)
sub create {
  my ($self,$type) = @_;
  my $filename = sprintf '%s/Adaptor%s/%s.pm',$self->base_path,$self->ns_path, $self->fp( $type );

  my $type_ky      = $self->ky( $type );
  my $conf         = $self->conf('objects',$type);
  my $uid_property = $conf->{'uid_property'}{'colname'}||'id',   ## %4$
  my $table_name   = $type_ky;
  my $alias_name   = exists $conf->{'aliasname'} ? $conf->{'aliasname'} : 'o';
  my @real_cols    =
    grep { ! (exists $_->{'multiple'} && $_->{'multiple'}) }
    grep { $_->{'type'} ne 'section' }
    @{$conf->{'properties'}||[]};
  my @multi_attribute_cols =
    grep { exists $_->{'multiple'} && $_->{'multiple'} }
    grep { $_->{'type'} ne 'section' }
    @{$conf->{'properties'}||[]};
  ## generate list of all columns....
  my @columns      = map { $_->{'colname'} } @real_cols;
  push @columns,
    map { $_->{'colname'} || (lc $self->ky( $_->{'object'}).'_id') }
    grep { $_->{'count'} ne 'many' && $_->{'count'} ne 'many-many' } @{$conf->{'has'}||[]};
  my $col_names = join q(, ), map { "$alias_name.$_" } @columns;
  local $Text::Wrap::unexpand = 0; ## no critic (PackageVars)
  $col_names = wrap( q(          '), q(           ), $col_names );

  ## generate list of audit columns...

  my $audit_columns = q();
  my $audit_flag = $self->conf('skip_audit') ? q() : $conf->{'audit'}||q();
  if( $audit_flag ) {
    $audit_columns .= ", $alias_name.created_at, $alias_name.updated_at" if $audit_flag =~ m{\btime\b}mxs;
    $audit_columns .= ", $alias_name.created_by, $alias_name.updated_by" if $audit_flag =~ m{\buser\b}mxs;
    $audit_columns .= ", $alias_name.ip, $alias_name.useragent"          if $audit_flag =~ m{\bip\b}mxs;
  }
  ## Generate additional column sets for "partial data queries"
  my $table_groups       = {};
  my $table_groups_multi = {};
  foreach my $coldef ( @real_cols ) {
    next unless exists $coldef->{'tables'};
    foreach ( @{$coldef->{'tables'}} ) {
      push @{$table_groups->{ $_ }}, $coldef->{'colname'};
    }
  }
  foreach my $coldef ( @multi_attribute_cols ) {
    next unless exists $coldef->{'tables'};
    foreach ( @{$coldef->{'tables'}} ) {
      $table_groups->{$_}||=[];
      push @{$table_groups_multi->{ $_ }}, $coldef->{'colname'};
    }
  }
  my $table_columns = q();
  my $table_tables  = q();
  my $table_methods = q();
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  foreach my $table ( sort keys %{$table_groups} ) {
    my @cols = map { "$alias_name.$_" } sort @{$table_groups->{$table}};
    if( exists $table_groups_multi->{$table} ) {
      my $idx = 0;
      my $partial_col_def   = q();
      my $partial_table_def = "$table_name $alias_name";
      foreach (@{$table_groups_multi->{$table}}) {
        $partial_table_def  = "($partial_table_def)" if $idx;
        $idx++;
        if( 1 ) {
          $partial_table_def .= "
 left join ${table_name}_$_ as a$idx on a$idx.$uid_property = $alias_name.$uid_property";
        } else {
          $partial_table_def .= "
 left join ${table_name}_$_ as r$idx on r$idx.$uid_property = $alias_name.$uid_property
 left join $_               as a$idx on a$idx.${_}_id = r$idx.${_}_id";
        }
        push @cols, qq(group_concat( distinct a$idx.$_ order by $_ separator ", " ) as partial_$_);
      }
      $table_tables .= sprintf q(
  '%1$s' => '%2$s',), $table, $partial_table_def;
      $table_methods .= sprintf q(

sub fetch_partial_%3$s_%4$ss {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)*
## Returns partial %2$s objects - suitable for "admin tables" & "public web usage"
  my $self = shift;
  my $sql = "
    select $TABLE_COLNAMES->{'%3$s'}
      from $TABLE_TABLES->{'%3$s'}
     group by d.%6$s
     order by d.%6$s";
  return [ map { $self->make_%4$s( $_, 1 ) }
               @{$self->all_hash( $sql )||[]} ];
}),
      $self->namespace,   ## %1$s
      $type,              ## %2$s
      $table,             ## %3$s
      $type_ky,           ## %4$s
      $table_name,        ## %5$s
      $uid_property,      ## %6$s
      $alias_name,        ## %7$s
      ;

    } else {
      $table_methods .= sprintf q(

sub fetch_partial_%3$s_%4$ss {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)*
## Returns partial %2$s objects - suitable for "admin tables" & "public web usage"
  my $self = shift;
  my $sql = "
    select $TABLE_COLNAMES->{'%3$s'}
      from %5$s %7$s
     order by d.%6$s";
  return [ map { $self->make_%4$s( $_, 1 ) }
               @{$self->all_hash( $sql )||[]} ];
}),
      $self->namespace,   ## %1$s
      $type,              ## %2$s
      $table,             ## %3$s
      $type_ky,           ## %4$s
      $table_name,        ## %5$s
      $uid_property,      ## %6$s
      $alias_name,        ## %7$s
      ;
    }
    $table_columns .= sprintf q(
  '%1$s' => '%2$s',), $table, join q(,
           ), @cols;
  }

  my $store_function_perl = sprintf q(
sub store {
#@params (self) (Pagesmith::Object::%1$s::%2$s object)
#@return (boolean)
## Store object in database
  my( $self, $my_object ) = @_;
  ## Check that the user has permission to write back to the db ##
  return $self->_update( $my_object ) if $my_object->uid;
  return $self->_store(  $my_object ); ## Now we perform the access options ##
}

sub _store {
#@params (self) (Pagesmith::Object::%1$s::%2$s object)
#@return (boolean)
## Create a new entry in database
}

sub _update {
#@params (self) (Pagesmith::Object::%1$s::%2$s object)
#@return (boolean)
## Create a new entry in database
}
),
    $self->namespace,   ## %1$s
    $type,              ## %2$s
    ;
  my $augment_method = q();
  my $augment_single = q();
  my $augment_multi  = q();
  if( @multi_attribute_cols ) {
    $augment_single = sprintf q(
  $self->augment( [$%s] );), $type_ky;
    $augment_multi  = sprintf q(
  $self->augment( $%ss );), $type_ky;
    my @additional_code;
    foreach my $attr_ref ( @multi_attribute_cols ) {
      my $sql = sprintf $attr_ref->{'multiple'} eq 'unique'   ||
                        $attr_ref->{'type'}     eq 'DropDown' ||
                        $attr_ref->{'type'}     eq 'YesNo'
              ? 'select %1$s_id, %2$s from %1$s_%2$s where %1$s_id'
              : 'select l.%1$s_id, t.%2$s from %1$s_%2$s l, %2$s t where l.%2$s_id = t.%2$s_id and l.%1$s_id',
        $type_ky, $attr_ref->{'code'};
      push @additional_code, sprintf q(
  $self->conn->run( 'fixup' =>  sub {
    my $sql = "%3$s in ($qs)";
    my $sth = $_->prepare( $sql );
    $sth->execute( @ids );
    my @row = $sth->fetchrow_array;
    foreach my $t (@{$%1$ss}) {
      while( @row && $row[0] == $t->uid ) {
        $t->{'obj'}{'%2$s'}{$row[1]}=1;
        @row = $sth->fetchrow_array;
      }
      last unless @row;
    }
    $sth->finish;
  } );
),      $type_ky, $attr_ref->{'code'}, $sql;
    }
    $augment_method = sprintf q(
sub augment {
  my( $self, $%1ss ) = @_;
  return unless @{$%1$ss};
  my @ids = map { $_->uid } @{$%1$ss};
  my $qs  = q(?).q(,?) x (@ids-1);%2$s
  return $self;
}
),    $type_ky, join q(), @additional_code;
  }
  my $perl = sprintf q(package Pagesmith::Adaptor::%1$s::%2$s;

## Adaptor for objects of type %2$s in namespace %1$s
%3$s
use Const::Fast qw(const);

## no critic (ImplicitNewlines)

const my $FULL_COLNAMES  =>
%5$s';

const my $AUDIT_COLNAMES => q(%8$s);

const my $TABLE_COLNAMES => {%9$s
};

const my $TABLE_TABLES => {%16$s
};

use base qw(Pagesmith::Adaptor::%1$s);
use Pagesmith::Object::%1$s::%2$s;
## Store/update functionality perl
## ===============================
%12$s

## Support methods to bless SQL hash & create empty objects...
## -----------------------------------------------------------

sub make_%4$s {
#@params (self), (string{} properties), (int partial)?
#@return (Pagesmith::Object::%1$s::%2$s)
## Take a hashref (usually retrieved from the results of an SQL query) and create a new
## object from it.
  my( $self, $hashref, $partial ) = @_;
  return Pagesmith::Object::%1$s::%2$s->new( $self, $hashref, $partial );
}

sub create {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)
## Create an empty object
  ## Check that the user has permission to write back to the db ##
  my $self = shift;
  return $self->make_%4$s({});
}%15$s

## Fetch methods..
## ===============

## Fetch all/one
## -------------

sub fetch_%4$ss {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)*
## Return all objects from database!
  my $self = shift;
  my $sql = "
    select $FULL_COLNAMES$AUDIT_COLNAMES
      from %6$s %11$s
     order by %7$s";
  my $%4$ss = [ map { $self->make_%4$s( $_ ) }
               @{$self->all_hash( $sql )||[]} ];%14$s
  return $%4$ss;
}%10$s

sub fetch_%4$s {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)?
## Return objects from database with given uid!
  my( $self, $uid ) = @_;
  my $sql = "
    select $FULL_COLNAMES$AUDIT_COLNAMES
      from %6$s %11$s
    where %11$s.%7$s = ?";
  my $%4$s_hashref = $self->row_hash( $sql, $uid );
  return unless $%4$s_hashref;
  my $%4$s = $self->make_%4$s( $%4$s_hashref );%13$s
  $self->dumper( $%4$s );
  return $%4$s;
}

## Fetch by relationships
## ----------------------

## use critic

1;

__END__

),
    $self->namespace,   ## %1$s
    $type,              ## %2$s
    $self->boilerplate, ## %3$s
    $type_ky,           ## %4$s
    $col_names,         ## %5$s
    $table_name,        ## %6$s
    $uid_property,      ## %7$s
    $audit_columns,     ## %8$s
    $table_columns,     ## %9$s
    $table_methods,     ## %10$s
    $alias_name,        ## %11$s
    $store_function_perl, ## %12$s
    $augment_single,    ## %13$s
    $augment_multi,     ## %14$s
    $augment_method,    ## %15$s
    $table_tables,      ## %16$s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}
## use critic

1;

