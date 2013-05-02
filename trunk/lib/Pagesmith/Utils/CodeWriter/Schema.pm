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

  foreach my $type ( $self->objecttypes ) {
    my $obj_conf = $self->conf( 'objects', $type );
    my $column_definitions=[];
    foreach my $prop_ref ( @{$obj_conf->{'properties'}||[]} ) {
      ## We have fake properties to define sections and stages in the form!
      next if $prop_ref->{'type'} eq 'section';
      $self->add_column( $column_definitions, $prop_ref );
    }
    foreach my $has_ref  ( @{$obj_conf->{'has'}||[]} ) {
      if( $has_ref->{'count'} eq 'many' ) {
        push @extra_rel_tables, [
          $type,
          $has_ref->{'object'},
          $has_ref->{'alias'}||$has_ref->{'object'},
          $has_ref->{'audit'}||q(),
        ];
      } else {
        my $col_name = $self->id( $has_ref->{'alias'} || $has_ref->{'object'} );
        push @{$column_definitions}, sprintf '  %-20s int unsigned not null', $col_name;
        push @{$column_definitions}, "    index              ( $col_name )";
      }
    }
    foreach my $index_ref ( @{$obj_conf->{'index'}||[]} ) {
      my @columns = @{$index_ref};
      my $key_type  = 'index ';
      if( $columns[0] eq 'unique' ) {
        $key_type = 'unique';
        shift @columns;
      }
      my $key_name = join q(_), @columns;
      push @{$column_definitions}, sprintf '    %s             %s (%s)',
        $key_type, $key_name, join q(, ), @columns;
    }
    if( exists $obj_conf->{'flags'} && any { $_ eq 'hr_name' } @{$obj_conf->{'flags'}} ) { ## Add tree tables...
      push @{$column_definitions},
        '  parent_id            int unsigned NOT NULL',
        '  l                    int unsigned NOT NULL',
        '    key                left_index  (l)',
        '    key                children    (parent_id,l)',
        '  r                    int unsigned NOT NULL',
        '    key                right_index (r)',
      ;
    }
    $self->add_audit_columns( $column_definitions, $obj_conf->{'audit'} );
    $table_definitions .= sprintf qq(create table %s (\n%s\n);\n\n), $self->ky($type), join qq(,\n), @{$column_definitions};
  }

## no critic (ImplicitNewlines)
  $table_definitions .= '
-- ----------------------------------------------------------------------
-- Many to many relationship definitions
-- ----------------------------------------------------------------------
' if @extra_rel_tables;
## use critic
  foreach my $rel ( @extra_rel_tables ) {
    my $column_definitions = [];
    my ( $primary, $secondary, $alias, $audit_flag ) = @{$rel};
    $primary   = $self->ky($primary);
    $secondary = $self->ky($secondary);
    $alias     = $self->ky($alias);
    push @{$column_definitions}, sprintf '  %-20s int unsigned not null', $primary.'_id';
    push @{$column_definitions}, sprintf '  %-20s int unsigned not null', $alias.'_id';
    push @{$column_definitions}, sprintf '    unique             rel_%s_%s ( %s_id, %s_id )',
      $primary, $alias, $primary, $alias;
    push @{$column_definitions}, sprintf '    unique             rel_%s_%s ( %s_id, %s_id )',
      $alias, $primary, $alias, $primary;
    $self->add_audit_columns( $column_definitions, $audit_flag );
    $table_definitions .= sprintf qq(create table %s_%s (\n%s\n);\n\n), $primary, $alias, join qq(,\n), @{$column_definitions};
  }

  foreach my $rel ( $self->relationships ) {
    my $rel_key = $self->ky( $rel );
    my $rel_conf = $self->conf( 'relationships', $rel );
    my $column_definitions;
    my @index;
    ## Assume for creating the schema that all foriegn keys are numeric int unsigned not null!
    ## Create the set of columns that are members of the foriegn unique key constraint....
    foreach my $obj_ref ( @{$rel_conf->{'objects'}||[]} ) {
      my $col_name = $self->id( $obj_ref->{'alias'}||$obj_ref->{'type'} );
      push @{$column_definitions}, sprintf '  %-20s int unsigned not null', $col_name;
      push @index, $col_name;
    }
    ## Now we loop through the properties... these are just raw column definitions... as in the base tables...
    foreach my $prop_ref ( @{$rel_conf->{'properties'}||[]} ) {
      $self->add_column( $column_definitions, $prop_ref );
      if( $prop_ref->{'index'} ) {
        push @index, $prop_ref->{'code'};
      }
    }
    $self->add_audit_columns( $column_definitions, $rel_conf->{'audit'} );
    push @{$column_definitions}, sprintf '    unique             %s (%s)', $rel_key.'_uniq', join q(, ), @index;
    $rel_definitions .= sprintf qq(create table %s (\n%s\n);\n\n), $rel_key, join qq(,\n), @{$column_definitions};
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

create database %1$s;
use    database %1$s;

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

  return $self->write_file( $filename, $sql );
}

sub col_def {
  my ( $self, $defn ) = @_;

  my $coltype = $self->defn_map( $defn->{'type'} )->{'sql'};
  my $size = $defn->{'size'}||0;

  $coltype  = 'varchar'   if $coltype eq 'text' && $size && $size < $ONE_BYTE;
  $coltype .= "($size)"   if $size;
  $coltype .= ' not null' unless $defn->{'required'} && $defn->{'required'} eq 'no';

  return $coltype;
}

sub add_column {
  my( $self, $cols, $p )  = @_;
  my $defn = sprintf '  %-20s %s', $p->{'colname'} || $p->{'code'}, $self->col_def( $p );
  my $uniq = $p->{'unique'}||q();
  if( 'uid' eq $uniq  ) {
    unshift @{$cols}, $defn.' auto_increment primary key';
    return $self;
  }
  push @{$cols}, $defn;
  if( '1' eq $uniq ) {
    push @{$cols}, sprintf '    unique             (%s)', $p->{'colname'} || $p->{'code'};
    return $self;
  }
  return $self;
}

sub add_audit_columns {
  my( $self, $cols, $audit_flag ) = @_;
  return unless $audit_flag;
  my $time_flag = 0;
  if( $audit_flag =~ m{\btime\b}mxs ) {
    $time_flag = 1;
    push @{$cols},
      "\n  created_at           timestamp    not null default current_timestamp",
      '    index              (created_at)',
      q(  updated_at           timestamp    not null default '0000-00-00 00:00:00'),
      '    index              (updated_at)';
  }
  if( $audit_flag =~ m{\buser\b}mxs ) {
    my $defn = 'varchar(64)  not null'; #2d# Add code here to switch to int unsigned if has user account table!
    push @{$cols},
      '  created_by           '.$defn,
      $time_flag ? '    index              (created_by,created_at)'
                 : '    index              (created_by)',
      '  updated_by           '.$defn,
      $time_flag ? '    index              (updated_by,updated_at)'
                 : '    index              (updated_by)';
  }
  if( $audit_flag =~ m{\bip\b}mxs ) {
    push @{$cols},
      '  ip                   varchar(64) not null',
      '    index              (ip)',
      '  useragent            varchar(255)  not null',
      '    index              (useragent)';
  }
  return $self;
}
## use critic
1;
