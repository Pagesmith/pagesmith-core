package Pagesmith::Utils::CodeWriter::Schema;

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

use List::MoreUtils qw(any);

use Const::Fast qw(const);
const my $ONE_BYTE => 256;

use base qw(Pagesmith::Utils::CodeWriter);

## no critic (ExcessComplexity)
sub create {
  my $self = shift;
  my $filename = sprintf '%s/sql/schema.sql', $self->root_path;

  my $table_definitions = q();
  my $rel_definitions   = q();
  my @extra_rel_tables;
  my @prop_tables;

  ## Loop over all object-types....
  foreach my $type ( $self->objecttypes ) {
    my $obj_conf = $self->conf( 'objects', $type );
    my $column_definitions = [];
    my $index_definitions  = [];

    ## Generate the main table SQL...
    push @{$column_definitions}, '            -- properties';
    push @{$index_definitions},  '            -- property indecies';
    foreach my $prop_ref ( @{$obj_conf->{'properties'}||[]} ) {
      ## We have fake properties to define sections and stages in the form!
      next if $prop_ref->{'type'} eq 'section';
      if( $prop_ref->{'multiple'} ) { ## We need to have an external entry here!
        ## We don't add a column but we have to push it onto the extra_rel_tables and extra_tables...
        if( $prop_ref->{'multiple'} eq 'unique' ||
            $prop_ref->{'type'}     eq 'DropDown' ||
            $prop_ref->{'type'}     eq 'YesNo' ) {  ## These lead to enums...
          push @prop_tables, [ $prop_ref, $type ];
        } else {
          push @prop_tables, [ $prop_ref ];
          push @extra_rel_tables, [
            $type,
            $prop_ref->{'code'},
            $prop_ref->{'colname'} || $prop_ref->{'code'},
            exists $prop_ref->{'audit'} ? $prop_ref->{'audit'} : $obj_conf->{'audit'},
          ];
        }
      } else {
        $self->add_column( $column_definitions, $index_definitions, $prop_ref );
      }
    }
    push @{$column_definitions}, '            -- has-a relationships';
    push @{$index_definitions},  '            -- has-a relationship indecies';
    foreach my $has_ref  ( @{$obj_conf->{'has'}||[]} ) {
      next if $has_ref->{'count'} eq 'many'; ## This is a many to 1 relationship and the
                                             ## Information is stored in the other schema..
      if( $has_ref->{'count'} eq 'many-many' ) {
        next if $self->ky($type) gt $self->ky($has_ref->{'alias'}||$has_ref->{'object'});
        push @extra_rel_tables, [
          $type,
          $has_ref->{'object'},
          $has_ref->{'alias'}||$has_ref->{'object'},
          exists $has_ref->{'audit'} ? $has_ref->{'audit'} : $obj_conf->{'audit'},
        ];
      } else {
        my $col_name = $self->id( $has_ref->{'alias'} || $has_ref->{'object'} );
        push @{$column_definitions}, sprintf '  %-32s int unsigned not null', $col_name;
        push @{$index_definitions}, "    index                          ($col_name)";
        push @{$index_definitions}, sprintf '    foreign key                    (%s) references %s (%s)',
          $col_name,  $self->ky( $has_ref->{'object'} ), $self->id( $has_ref->{'object'} );
      }
    }
    push @{$index_definitions},  '            -- additional indecies';
    foreach my $index_ref ( @{$obj_conf->{'index'}||[]} ) {
      my @columns = @{$index_ref};
      my $key_type  = 'index ';
      if( $columns[0] eq 'unique' ) {
        $key_type = 'unique';
        shift @columns;
      }
      my $key_name = join q(_), @columns;
      push @{$index_definitions}, sprintf '    %s                         %s (%s)',
        $key_type, $key_name, join q(, ), @columns;
    }
    if( exists $obj_conf->{'flags'} && any { $_ eq 'tree' } @{$obj_conf->{'flags'}} ) { ## Add tree tables...
      push @{$index_definitions},  '            -- tree columns';
      push @{$column_definitions},
        '  parent_id            int unsigned NOT NULL',
        '  l                    int unsigned NOT NULL',
        '  r                    int unsigned NOT NULL',
        ;
      push @{$index_definitions},  '            -- tree indecies';
      push @{$index_definitions},
        '    key                left_index  (l)',
        '    key                children    (parent_id,l)',
        '    key                right_index (r)',
        sprintf '    foreign key        (parent_id) references %s(%s)', $self->ky($type),$self->id($type),
        ;
    }
    $index_definitions->[0] = "\n$index_definitions->[0]" if @{$index_definitions};

    $self->add_audit_columns( $column_definitions, $index_definitions, $obj_conf->{'audit'} );
    $table_definitions .= sprintf qq(create table %s (\n%s\n);\n\n), $self->ky($type),
      $self->merge( @{$column_definitions}, @{$index_definitions} );
    ## Do we have any initial_data...
    if( exists $obj_conf->{'sample_data'} ) {
      foreach my $row ( @{$obj_conf->{'sample_data'}} ) {
        my @columns = sort keys %{$row};
        my @values  = @{$row}{@columns};
        ## no critic (ImplicitNewlines)
        $table_definitions .= sprintf q(
insert into %s (%s) values(%s);), $self->ky( $type ),
          ( join q(,), @columns ),
          join q(, ), map { sprintf q('%s'), $self->addslash($_) } @values;
        ## use critic
      }
      $table_definitions .= qq(\n\n);
    }
  }

## no critic (ImplicitNewlines InterpolationOfMetachars)
  $table_definitions .= '
-- ----------------------------------------------------------------------
-- Object property tables
-- ----------------------------------------------------------------------
' if @prop_tables;
  my $tables_generated = {};
  foreach my $ref ( @prop_tables ) {
    my( $prop_ref, $type ) = @{$ref};
    my $table_name = $prop_ref->{'colname'};
    my $col_def = $self->col_def( $prop_ref, 1 );
    if( $type ) {
      $table_name = $self->ky( $type ).q(_).$table_name;
      $table_definitions .= sprintf '
create table %1$s (
  %2$-32s int unsigned not null auto_increment primary key,
  %3$-32s int unsigned not null,
  %5$-32s %4$s,
  unique                           (%3$s, %5$s),
  unique                           (%5$s, %3$s),
  foreign key                      (%3$s) references %6$s (%3$s)
);
',
        $table_name,                ## %1$s
        $table_name.'_id',          ## %2$s
        $self->id( $type ),         ## %3$s
        $col_def,                   ## %4$s
        $prop_ref->{'colname'},     ## %5$s
        $self->ky( $type ),         ## %6$s
        ;
    } else {
      next if $tables_generated->{$table_name}++;
      $table_definitions .= sprintf '
create table %1$s (
  %2$-32s int unsigned not null auto_increment primary key,
  %1$-32s %3$s,
  unique                           (%1$s)
);
',
        $table_name,                ## %1$s
        $table_name.'_id',          ## %2$s
        $col_def,                   ## %3$s
        ;
    }
  }
  $table_definitions .= '
-- ----------------------------------------------------------------------
-- Many to many relationship definitions
-- ----------------------------------------------------------------------
' if @extra_rel_tables;
## use critic
  foreach my $rel ( @extra_rel_tables ) {
    my $column_definitions = [];
    my $index_definitions  = [];
    my ( $primary, $secondary, $alias, $audit_flag ) = @{$rel};
    $primary   = $self->ky($primary);
    $secondary = $self->ky($secondary);
    $alias     = $self->ky($alias);
    push @{$column_definitions}, sprintf '  %-32s int unsigned not null', $primary.'_id';
    push @{$column_definitions}, sprintf '  %-32s int unsigned not null', $alias.'_id';
    push @{$index_definitions}, sprintf '    unique                         rel_%s_%s ( %s_id, %s_id )',
      $primary, $alias, $primary, $alias;
    push @{$index_definitions}, sprintf '    unique                         rel_%s_%s ( %s_id, %s_id )',
      $alias, $primary, $alias, $primary;
    push @{$index_definitions}, sprintf '    foreign key                    (%s_id) references %s (%s_id)', $primary, $primary, $primary;
    push @{$index_definitions}, sprintf '    foreign key                    (%s_id) references %s (%s_id)', $alias, $secondary, $secondary;
    $self->add_audit_columns( $column_definitions, $index_definitions, $audit_flag );
    $index_definitions->[0] = "\n$index_definitions->[0]" if @{$index_definitions};
    $table_definitions .= sprintf qq(create table %s_%s (\n%s\n);\n\n), $primary, $alias,
      $self->merge( @{$column_definitions}, @{$index_definitions} );
  }

  ## Now the main relationship tables...
  foreach my $rel ( $self->relationships ) {
    my $rel_key = $self->ky( $rel );
    my $rel_conf = $self->conf( 'relationships', $rel );
    my $index_definitions  = [];
    my $column_definitions = [];
    my @index;

    ## Assume for creating the schema that all foriegn keys are numeric int unsigned not null!
    ## Create the set of columns that are members of the foriegn unique key constraint....
    push @{$column_definitions}, '            -- related_objects';
    foreach my $obj_ref ( @{$rel_conf->{'objects'}||[]} ) {
      my $col_name = $self->id( $obj_ref->{'alias'}||$obj_ref->{'type'} );
      push @{$column_definitions}, sprintf '  %-32s int unsigned not null', $col_name;
      push @{$index_definitions},  sprintf '    foreign key                    (%s) references %s (%s)',
      $col_name, $self->ky( $obj_ref->{'type'} ), $self->id( $obj_ref->{'type'} );
      push @index, $col_name;
    }
    ## Now we loop through the properties... these are just raw column definitions... as in the base tables...
    push @{$column_definitions}, '            -- properties';
    foreach my $prop_ref ( @{$rel_conf->{'properties'}||[]} ) {
      $self->add_column( $column_definitions, $index_definitions, $prop_ref );
      if( $prop_ref->{'index'} ) {
        push @index, $prop_ref->{'code'};
      }
    }

    push @{$index_definitions}, sprintf '    unique                         %s (%s)', $rel_key.'_uniq', join q(, ), @index;
    my $index_id = 0;
    push @{$index_definitions},  '            -- additional indicies';

    foreach my $index_ref ( @{$rel_conf->{'index'}||[]} ) {
      my $key_type = 'key';
      $key_type = shift @{$index_ref} if $index_ref->[0] eq 'unique';
      my $key_id = join q(_), @{$index_ref};
      $index_id++;
      push @{$index_definitions}, sprintf '    %6s                         %s_%d (%s)',
        $key_type, $key_type,$index_id, join q(, ), @{$index_ref};
    }

    $self->add_audit_columns( $column_definitions, $index_definitions, $rel_conf->{'audit'} );
    $index_definitions->[0] = "\n$index_definitions->[0]" if @{$index_definitions};
    $rel_definitions .= sprintf qq(create table %s (\n%s\n);\n\n), $rel_key,
      $self->merge( @{$column_definitions}, @{$index_definitions} );
  }
  $self->boilerplate;
## no critic (ImplicitNewlines InterpolationOfMetachars)
  my $sql = sprintf q(-- ----------------------------------------------------------------------
--
-- SQL schema definition for database %1$s
--
-- Pagesmith object model: %2$s
--
-- Generated by %3$s <%4$s> on %5$s
--
-- ----------------------------------------------------------------------

drop database if exists %1$s;
create database %1$s;
use    %1$s;
SET foreign_key_checks = 0;

-- ----------------------------------------------------------------------
--
-- Object table definitions
--
-- ----------------------------------------------------------------------

%6$s

-- ----------------------------------------------------------------------
--
-- Relationship table definitions
--
-- ----------------------------------------------------------------------

%7$s

SET foreign_key_checks = 1;
),
    $self->conf('database','name'), # %1$s
    $self->namespace,               # %2$s
    $self->conf('realname'),        # %3$s
    $self->conf('username'),        # %4$s
    $self->conf('today'),           # %5$s
    $table_definitions,             # %6$s
    $rel_definitions,               # %7$s
    ;
## use critic
  $sql =~ s{^(\s+--.*?),$}{$1}mxg; ## no critic (DotMatchAnything)
  return $self->write_file( $filename, $sql );
}

sub col_def {
  my ( $self, $defn, $force_required ) = @_;

  my $sql_defn = $self->defn_map( $defn->{'type'} );
  my $coltype  = $sql_defn->{'sql'};
  my $size = $defn->{'size'}||0;

  $coltype  = 'varchar'   if $coltype eq 'text'    && $size && $size < $ONE_BYTE;
  $coltype  = 'text'      if $coltype eq 'varchar' && $size && $size >= $ONE_BYTE;

  $size = $ONE_BYTE-1 if $coltype eq 'varchar' && !$size;
  $coltype .= "($size)"   if $size;

  my $optional = $force_required ? 0 : ($defn->{'optional'} ? $defn->{'optional'} : 0);

  if( $coltype eq 'enum' ) {
    my $values = $defn->{'values'} || $sql_defn->{'values'} || [];
    my @values;
    if( 'HASH' eq ref $values ) {
      @values = keys %{$values};
    } else {
      @values = @{$values};
    }
    $coltype .= sprintf '(%s)', join q(,), map { sprintf q('%s'), $self->addslash($_) } @values;
  }
  my $default = $defn->{'default'}||$sql_defn->{'default'};
     $default = q(No)  if $defn->{'type'} eq 'YesNo' && ! defined $default;
     $default = q()    unless defined $default;
  $optional = 1 if $sql_defn->{'sql'} eq 'enum' && $default eq q();

  unless( $optional ) {
    $coltype .= ' not null';
    $coltype .= $sql_defn->{'flag'} eq 'no'
              ? " default $default"
              : sprintf q( default '%s'), $self->addslash($default)
    if defined $default &&
       $sql_defn->{'sql'} ne 'text' &&
       $sql_defn->{'sql'} ne 'blob' &&
       !( exists $defn->{'unique'} && $defn->{'unique'} eq 'uid' );
  }
  return $coltype;
}

sub add_column {
  my( $self, $cols, $indexes, $p )  = @_;
  my $defn = sprintf '  %-32s %s', $p->{'colname'} || $p->{'code'}, $self->col_def( $p );
  my $uniq = $p->{'unique'}||q();
  if( 'uid' eq $uniq  ) {
    unshift @{$cols}, $defn.' auto_increment primary key';
    return $self;
  }
  push @{$cols}, $defn;
  if( '1' eq $uniq ) {
    push @{$indexes}, sprintf '    unique                         (%s)', $p->{'colname'} || $p->{'code'};
    return $self;
  }
  return $self;
}

sub add_audit_columns {
  my( $self, $cols, $indexes, $audit_flag ) = @_;
  return if $self->no_audit;
  return unless $audit_flag;
  push @{$cols},     '            -- audit columns';
  push @{$indexes},  '            -- audit indecies';

  my $time_flag = 0;
  if( $audit_flag =~ m{\btime\b}mxs ) {
    $time_flag = 1;
    push @{$cols},
      q(        created_at                 timestamp    not null default current_timestamp),
      q(        updated_at                 timestamp    not null default '0000-00-00 00:00:00'),
      ;
    push @{$indexes},
      '    index                          (created_at)',
      '    index                          (updated_at)',
      ;
  }
  if( $audit_flag =~ m{\buser\b}mxs ) {
    my $defn = $self->user_audit_is_id ? 'int unsigned not null default 0' : q(varchar(64)  not null default '-');
    push @{$cols},
      '        created_by                 '.$defn,
      '        updated_by                 '.$defn,
      ;
    push @{$indexes},
      $time_flag ? '    index                          (created_by,created_at)'
                 : '    index                          (created_by)',
      $time_flag ? '    index                          (updated_by,updated_at)'
                 : '    index                          (updated_by)';
    push @{$indexes}, q(    foreign key            (created_by) references user (user_id) ),
                      q(    foreign key            (updated_by) references user (user_id) ) if $self->user_audit_is_id;
  }
  if( $audit_flag =~ m{\bip\b}mxs ) {
    push @{$cols},
      q(        ip                         varchar(64)  not null default ''),
      q(        useragent                  varchar(255) not null default '-'),
      ;
    push @{$indexes},
      '    index                          (ip)',
      '    index                          (useragent)',
      ;
  }
  return $self;
}
## use critic
sub merge {
  my( $self, @lines ) = @_;
  my @sql = q();
  my $ending = q();
  foreach ( reverse @lines ) {
    if( m{\A\s*--}mxs ) {
      unshift @sql, $_;
      next;
    }
    unshift @sql, "$_$ending";
    $ending = q(,);
  }
  return join "\n", @sql;
}

1;
