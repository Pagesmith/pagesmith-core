#!/usr/bin/perl

## Generate code...
## Author         : js5
## Maintainer     : js5
##   created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

### Use modules required by bootstrap!
### ---------------------------------------------------------------------------------------
use Cwd qw(abs_path);
use English qw(-no_match_vars $PROGRAM_NAME);
use File::Basename qw(dirname);
use List::Util qw(pairs);

my $ROOT_PATH;
my @libs;

### We will need to include all module paths here that we can find (lib, and everything in
### sites/*/lib & plugins/*/lib)
### ---------------------------------------------------------------------------------------

BEGIN {
  $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME)));
  @libs = ( "$ROOT_PATH/lib" );
  foreach my $d (qw(sites plugins)) {
    if( opendir my $dh, "$ROOT_PATH/$d" ) {
      push @libs, grep { -e $_ } map  { "$ROOT_PATH/$d/$_/lib" } grep { ! m{\A[.]}mxs } readdir $dh;
      closedir $dh;
    }
  }
}

use lib @libs;

###########################################################################################
### Now we have included everything we can start in earnest!                            ###
###########################################################################################

### Use required modules!
### ---------------------------------------------------------------------------------------

use Getopt::Long    qw(GetOptions);
use Const::Fast     qw(const);
use File::Path      qw(make_path);

const my $LEN_LIB    => -4;
const my $SHORT_SIZE => 20;
const my $MED_SIZE   => 35;

use Pagesmith::Root;
use Pagesmith::Core qw(user_info);

### Set up constants...
###  * EL_MAP -> maps config keys -> form object types & SQL column types!
### ---------------------------------------------------------------------------------------

const my %EL_MAP => (
# conftype         Form Object    SQL type
  'boolean'   => [ 'YesNo',       q(enum ('yes','no'))  ],
  'date'      => [ 'Date',        'date'                ],
  'datetime'  => [ 'DateTime',    'datetime'            ],
  'time'      => [ 'Time',        'time'                ],
  'double'    => [ 'Float',       'double'              ],
  'url'       => [ 'URL',         'varchar(511)'        ],
  'uri'       => [ 'URI',         'varchar(511)'        ],
  'email'     => [ 'Email',       'varchar(128)'        ],
  'string'    => [ 'String',      'varchar(2047)'       ],
  'text'      => [ 'Text',        'text'                ],
  'blob'      => [ 'File',        'blob'                ],
  'image'     => [ 'Image',       'blob'                ],
  'int'       => [ 'Int',         'int'                 ],
  'posint'    => [ 'PosInt',      'int unsigned'        ],
  'nonnegint' => [ 'NonNegInt',   'int unsigned'        ],
);

### Parse options
###  * quite
###  * verbose
###  * force
###  * db_name
###  * act_map
### ---------------------------------------------------------------------------------------

my $quiet   = 0;
my $verbose = 0;
my $force   = 0;
my $db_name = q();
my $act_map = q();
my ($act_map_from,$act_map_to);

GetOptions(
  'quite+'       => \$quiet,
  'verbose+'     => \$verbose,
  'force'        => \$force,
  'db_name:s'    => \$db_name,
  'act_map:s'    => \$act_map,
);

if( $act_map ) {
  ($act_map_from,$act_map_to) = split m{:}mxs, 'action/'.$act_map.q(/);
  $act_map_from .= q(_);
}

### Get namespace
### and get support module for name space
###  * check it exists
###  * check we can use it
###  * check it has a bake_model call in it
### ---------------------------------------------------------------------------------------

## A namespace must be defined!
_die_with_docs( 'You must specify a name space' ) unless @ARGV;
my $ns = shift @ARGV;

## Name space needs to be of form Abc, Abc::Def, Abc::Def::Ghi etc....
_die_with_docs( 'Not a valid perl name space' ) unless $ns =~ m{\A[[:upper:]]\w*(::[[:upper:]]\w*)*\Z}mxs;

(my $_ns      = $ns )=~s{::}{_}mxsg;          ## For use in Component/Actions...
 my $rt       = Pagesmith::Root->new;         ## Root module so we can use dynamic_use!
 my $mod      = "Pagesmith::Model::$ns";      ## Get model definition Namespace ...
(my $mod_file = "$mod.pm" ) =~ s{::}{/}mxsg;  ## ... & filename...

warn qq(
========================================================================

  Perl modules in "$ns" namespace

   * Setting up definition from module: $mod

========================================================================

  Creating following files:
) unless $quiet;

unless( $rt->dynamic_use( $mod ) ) { ## Check to see if we can include it!
  my $msg = $rt->dynamic_use_failure( $mod );
  die "\n" if index $msg, "Can't locate $mod_file in \@INC (\@INC";
  die "No $mod module in file path\n\n";
}

die "Module $mod doesn't call bake\n\n" unless $mod->can( 'auto_methods' );

### Get the boilerplate code, code templates & also the lib path the Support module
### is stored in....
### ---------------------------------------------------------------------------------------

( my $library_root = $INC{$mod_file} ) =~ s{Pagesmith/Model/.*}{}mxs;
my $bp        = _perl_boilerplate( );
my $templates = _get_templates();


### ---------------------------------------------------------------------------------------
### Finally generate files if required
###  * Main "core" adaptors
###  * type objects & adaptors
###  * relationship adaptors (*)
###  * admin action (R/D - table/remove) & admin form (C/U - add/update)
###  * create a draft SQL schema for object models...
### ---------------------------------------------------------------------------------------

generate_core_modules();
generate_adaptors_and_objects();
generate_navigation_component();
generate_admin_methods();
generate_documentation();
generate_schema();
db_config_note();

exit;

########################################################################
##+------------------------------------------------------------------+##
##| END OF SCRIPTS - METHODS TO FOLLOW.....                          |##
##+------------------------------------------------------------------+##
########################################################################

###########################################################################################
### Now code which generates the files...                                               ###
###########################################################################################

sub generate_navigation_component {
  _write_heading( 'Admin navigation panel component' );
  my $module_name = 'Pagesmith::Component::'.$ns.'::Navigation';
  ( my $module_file = "$library_root$module_name.pm" ) =~ s{::}{/}mxsg;
  if( !$force && -e $module_file ) {
    warn "     * Skipping file.... $module_file\n" unless $quiet;
    return;
  }
  my @al;
  my $defn_method = $mod.'::type_defn';
  foreach ($mod->my_obj_types) {
    no strict 'refs'; ## no critic (NoStrict)
    my $definition = &{$defn_method}( $_ );
    use strict;
    next unless exists $definition->{'admin'};
    my $at  = $definition->{'admin'};
    my $pl  = exists $definition->{'plural'} ? $definition->{'plural'} : lc $_.'s';
    ## no critic (InterpolationOfMetachars)
    push @al, sprintf q(push @links, [ '/action/%s_Admin_%s', 'Administer %s' ] if $self->me->is_%s;),
      $_ns, $_, $pl, $at->{'by'};
    ## use critic
  }
  _write_file( $module_file, 'Component-Navigation', { 'admin_links' => join qq(\n  ), @al } );
  return;
}

sub generate_core_modules {
  my @list = qw(Action Adaptor Component MyForm MyForm-Admin Object Support);
  _write_heading( 'Base modules' );

  foreach my $stub_type ( @list ) {
    my @parts = split m{-}mxs, $stub_type;
    my $module_name = @parts > 1 ? "Pagesmith::$parts[0]::$ns"."::$parts[1]" : "Pagesmith::$parts[0]::$ns";
    ( my $module_file = "$library_root$module_name.pm" ) =~ s{::}{/}mxsg;
    if( !$force && -e $module_file ) {
      warn "     * Skipping file.... $module_file\n" unless $quiet;
      next;
    }
    _write_file( $module_file, $stub_type );
  }
  return;
}

sub generate_adaptors_and_objects {
  _write_heading( 'Object/Adaptor modules');
  foreach my $obj_type ( $mod->my_obj_types ) {
    ## Create adaptor, object and admin interfaces!
    foreach my $type ( qw(Adaptor Object) ) {
      my $module_name = join q(::), 'Pagesmith', $type, $ns, $obj_type;
      ( my $module_file = "$library_root$module_name.pm" ) =~ s{::}{/}mxsg;
      if( !$force && -e $module_file ) {
        warn "     * Skipping file.... $module_file\n" unless $quiet;
        next;
      }
      _write_file( $module_file, "type:$type", { 'ot' => $obj_type } );
    }
  }
  _write_heading( 'Relationship adaptor modules');
  foreach my $obj_type ( $mod->my_rel_types ) {
    my $module_name = join q(::), 'Pagesmith', 'Adaptor', $ns, $obj_type;
    ( my $module_file = "$library_root$module_name.pm" ) =~ s{::}{/}mxsg;
    if( !$force && -e $module_file ) {
      warn "     * Skipping file.... $module_file\n" unless $quiet;
      next;
    }
    _write_file( $module_file, 'type:Adaptor', { 'ot' => $obj_type } );
  }
  return;
}

## no critic (ExcessComplexity)
sub generate_admin_methods {
  _write_heading( 'Admin table view actions & forms');
  foreach my $obj_type ( $mod->my_obj_types ) {
    my $defn_method = $mod.'::type_defn';

    no strict 'refs'; ## no critic (NoStrict)
    my $definition = &{$defn_method}( $obj_type );
    next unless $definition->{'admin'};
    my $admin_type = $definition->{'admin'};
    use strict;

    my @table_columns;
    my @table_extra;
    my @form_entries;
    my @form_extra    = (q());
    my @form_elements = (q());
    foreach ( pairs @{$definition->{'properties'}} ) {
      my ($prop, $p_def ) = @{$_};
      $p_def = { 'type' => $p_def } unless ref $p_def;
      ( my $hr_col_name = ucfirst $prop ) =~ s{_}{ }mxsg;
      if( $p_def->{'type'} eq 'uid' ) {
        unshift @form_elements, q(## Unique_ID),form_add( 'Hidden', $prop ).'->set_optional;';
        unshift @table_columns, sprintf q('key' => 'get_%s', 'label' => '%s', 'format' => 'd'),
          $prop, $hr_col_name;
        push @table_extra, sprintf q('key' => '_edit', 'label' => 'Edit?', 'template' => 'Edit', 'align' => 'c', 'no_filter' => 1,
          'link' => '/form/%s_Admin_%s/[[h:uid]]'), $ns, $obj_type;
        if( exists $p_def->{'remove'} ) {
          push @table_extra, sprintf q('key' => '_remove', 'label' => 'Delete?', 'template' => 'Delete', 'align' => 'c', 'no_filter' => 1,
            'link' => q(class=confirm-click {msg:'Are you sure you want to delete - [[h:get_name]]'} /action/%s_Admin_%s/[[h:uid]]/remove)), $ns, $obj_type;
        }
        next;
      }
      push @form_entries, $prop;
      push @table_columns, sprintf q('key' => 'get_%s', 'label' => '%s'), $prop, $hr_col_name;
      ## no critic (InterpolationOfMetachars CascadingIfElse)
      if( $p_def->{'type'} eq 'boolean' ) {
        push @form_elements, form_add( 'YesNo', $prop );
        push @form_elements, sprintf q[     ->set_default_value(   '%s' )], $p_def->{'default'} if $p_def->{'default'};
      } elsif( exists $EL_MAP{ $p_def->{'type'} } ) {
        push @form_elements, form_add( $EL_MAP{ $p_def->{'type'} }[0], $prop );
      } elsif( $p_def->{'type'} eq 'enum' ) {
        push @form_elements, form_add( 'DropDown', $prop );
        my $pl  = exists $p_def->{'plural'} ? $p_def->{'plural'} : $prop.'s';
        unshift @form_extra, sprintf q(my $%-15s = $self->adaptor( '%s' )->all_%s_sorted;),
          $pl, $obj_type, $prop;
        push @form_elements,       q[     ->set_firstline(   '== select ==' )],
        sprintf q[     ->set_values(      [ map { { 'value' => $_->[0], 'name' => $_->[1] } } @{$%1$s} ] );],
          $pl;
        ## Get values for this property!!
      } elsif( $p_def->{'type'} eq 'string' ) {
        my $real_type = exists $p_def->{'length'} ? 'String' : 'Text';
        push @form_elements, form_add( $real_type, $prop );
        if( exists $p_def->{'length'} ) {
          if( $p_def->{'length'} < $SHORT_SIZE ) {
            push @form_elements, q(     ->add_class(       'short' ));
          } elsif( $p_def->{'length'} < $MED_SIZE ) {
            push @form_elements, q(     ->add_class(       'medium' ));
          }
        }
      } else {
        push @form_elements, form_add( ucfirst $p_def->{'type'}, $prop );
      }
      ## use critic
      $form_elements[-1] .= q(;);
    }
    foreach ( pairs @{$definition->{'related'}} ) {
      my ($rel, $r_def ) = @{$_};
      next unless exists $r_def->{'to'};

      (my $vname = $rel ) =~ s{_id\Z}{}mxs;
      no strict 'refs'; ## no critic (NoStrict)
      my $rel_defn = &{$defn_method}( $r_def->{'to'} );
      use strict;
      ## no critic (InterpolationOfMetachars)
      unshift @form_extra, sprintf q(my $%-15s = $self->adaptor( '%s' )->fetch_all_%s;),
        $vname.'s', $r_def->{'to'}, exists $rel_defn->{'plural'} ? $rel_defn->{'plural'} : lc $r_def->{'to'}.'s';
      push @form_elements, form_add( 'DropDown', $rel );
      push @form_elements,         q[     ->set_firstline(   '== select ==' )],
                           sprintf q[     ->set_caption(     '%s' )],$r_def->{'to'};
      my @cols      = sort keys %{$r_def->{'derived'}||{}};
      my @cols_name = sort values %{$r_def->{'derived'}||{}};
      push @form_entries, $rel;
      if( @cols ) {
        push @table_columns, sprintf q('key' => 'get_%s', 'label' => '%s', template => '%s', ),
          $rel, uc $vname, join q( - ), map { sprintf '[[h:get_%s]]', $_ } @cols_name;
      } else {
        @cols = (lc $r_def->{'to'}.'_id');
        push @table_columns, sprintf q('key' => 'get_%s', 'label' => '%s'), $rel, uc $vname;
      }
      if(@cols>1){
        push @form_elements,
          sprintf q[     ->set_values(      [ map { { 'value' => $_->uid, 'name' => join q( - ), %2$s } } @{$%1$ss} ] );],
            $vname, join q(, ), map { sprintf '$_->get_%s', $_ } @cols;
      } else {
        push @form_elements,
          sprintf q[     ->set_values(      [ map { { 'value' => $_->uid, 'name' => %2$s } } @{$%1$ss} ] );],
            $vname, join q(, ), map { sprintf '$_->get_%s', $_ } @cols;
      }
      ## use critic
    }
    foreach my $type ( qw(Action MyForm) ) {
      my $module_name = join q(::), 'Pagesmith', $type, $ns, 'Admin', $obj_type;
      ( my $module_file = "$library_root$module_name.pm" ) =~ s{::}{/}mxsg;
      if( !$force && -e $module_file ) {
        warn "     * Skipping file.... $module_file\n" unless $quiet;
        next;
      }
      my $conf = {
        'ot' => $obj_type,
        'at' => $admin_type,
        'cc_ot'=> exists $definition->{'plural'} ? $definition->{'plural'} : lc $obj_type.'s',
        'form_entries'  => "@form_entries",
        'table_columns' => join qq(\n        ), map { "{ $_ }," } @table_columns, @table_extra,
      };
      $conf->{'form_elements'} = join "\n    ", @form_extra,@form_elements;
      _write_file( $module_file, "type:$type-Admin", $conf );
    }
  }
  return;
}
## use critic

sub form_add {
  my( $el_type, $prop ) = @_;
  $el_type = sprintf q(%-24s),"'$el_type',";
  return sprintf q[$self->add(           %s '%s' )], $el_type, $prop; ## no critic (InterpolationOfMetachars)
}

########################################################################
##+------------------------------------------------------------------+##
##| Generate documentation of default fns....                        |##
##+------------------------------------------------------------------+##
########################################################################

sub generate_documentation {
  ## Generate documentation!
  my $docs = {};
  foreach my $type ( qw(Adaptor Model Support) ) {
    my $module_name = join q(::), 'Pagesmith', $type, $ns;
    $rt->dynamic_use( $module_name );
    $docs->{$module_name} = $module_name->dump_methods;
  }

  foreach my $type ( $mod->my_rel_types ) {
    my $module_name = join q(::), 'Pagesmith', 'Adaptor', $ns, $type;
    $rt->dynamic_use( $module_name );
    $docs->{$module_name} = $module_name->dump_methods;
  }

  foreach my $type ( qw(Adaptor Object) ) {
    foreach my $obj_type ( $mod->my_obj_types ) {
    ## Create adaptor, object and admin interfaces!
      my $module_name = join q(::), 'Pagesmith', $type, $ns, $obj_type;
      $rt->dynamic_use( $module_name );
      $docs->{$module_name} = $module_name->dump_methods;
    }
  }

  my $docs_file = (substr $library_root, 0, $LEN_LIB). lc "docs/$_ns.txt";
  _write_heading( 'Documentation file');
  _write_file( $docs_file, 'docs', { 'docs' => join q(), map { $docs->{$_} } sort keys %{$docs} } );

  return;
}

########################################################################
##+------------------------------------------------------------------+##
##| SQL SCHEMA GENERATION AND SUPPORT METHODS                        |##
##+------------------------------------------------------------------+##
########################################################################

sub get_obj_table_sql {
  my $obj_type    = shift;

  ## Get definition...
  my $defn_method = $mod.'::type_defn';
  no strict 'refs'; ## no critic (NoStrict)
  my $definition = &{$defn_method}( $obj_type );
  use strict;

  ## Now create table sql
  my @columns;
  _define_column( \@columns, @{$_} ) foreach pairs @{$definition->{'properties'}};
                  ## property and it's definition!
  foreach ( pairs @{$definition->{'related'}||[]} ) {
    my( $prop, $p_def ) = @{$_};
    next unless exists $p_def->{'to'};    ## This is one-to-many relationship so not store in this table!
    next if     exists $p_def->{'audit'}; ## Already included in audit column definition!
    push @columns, sprintf '%s int unsigned not null', $prop;
    push @columns, sprintf '  index fk_%s (%s)', $prop, $prop;
  }
  ## We need to add autdit columns now...!
  ## Need to add audit columns if required....
  push @columns, _audit_columns( $definition->{'audit'} ) if exists $definition->{'audit'};
  ## no critic (InterpolationOfMetachars)
  return sprintf '
-- Table %1$s - stores details of %2$s::%3$s objects

drop table if exists %1$s;
create table %1$s (
  %4$s
);
', lc $obj_type,  $ns, $obj_type,  join qq(,\n  ), @columns;
  ## use critic
}

sub get_rel_table_sql {
  my $rel_type    = shift;

  ## Get definition...
  my $defn_method = $mod.'::type_defn';
  no strict 'refs'; ## no critic (NoStrict)
  my $definition = &{$defn_method}( $rel_type );
  use strict;

  ## Now create table sql
  my @columns;
  my @unique;
  foreach ( pairs @{$definition->{'objects'}} ) {
    my( $col_name, $ottype) = @{$_};
    push @columns, sprintf '%s int unsigned not null', $col_name;
    push @columns, sprintf '  index fk_%s (%s)', $col_name, $col_name;
    push @unique, $col_name;
  }
  foreach (pairs @{$definition->{'additional'}}) {
    my( $col_name, $dfn) = @{$_};
    _define_column( \@columns, @{$_} );
    push @unique, $col_name if exists $dfn->{'in_unique'} && $dfn->{'in_unique'};
  }
  ## Create unique index...!
  push @columns, _audit_columns( $definition->{'audit'} ) if exists $definition->{'audit'};
  push @columns, sprintf '  unique un_%s (%s)', lc $rel_type, join q(, ), @unique;
                  ## property and it's definition!
  ## no critic (InterpolationOfMetachars)
  return sprintf '
-- Table %1$s - stores details of %2$s::%3$s relationships

drop table if exists %1$s;
create table %1$s (
  %4$s
);
', lc $rel_type,  $ns, $rel_type, join qq(,\n  ), @columns;
   ## use critic
}
sub generate_schema {
  ## Get schema filename and check to see if we need to create it!
  ## Compute the location of the schema file
  ## If it exists and we haven't said force then we will skip this block of code
  _write_heading( 'Schema definition files');
  my $schema_file = (substr $library_root, 0, $LEN_LIB). lc "sql/$_ns.sql";
  if( !$force && -e $schema_file ) {
    warn "     * Skipping file.... $schema_file\n" unless $quiet;
    return;
  }
  my $o_tables = join q(), map { get_obj_table_sql( $_ ) } sort $mod->my_obj_types;
  my $r_tables = join q(), map { get_rel_table_sql( $_ ) } sort $mod->my_rel_types;

  ##------------------------------------------------------------------
  my $ui = user_info();
  _write_file( $schema_file, 'schema', {
    'mod_file' => $mod,
    'user'     => "$ui->{'name'} <$ui->{'username'}\@".$mod->mail_domain.q(>),
    'dt'       => $rt->time_str( '%o %h %Y', time ),
    'dbname'   => $db_name || lc $_ns,
    'obj_tables' => $o_tables,
    'rel_tables' => $r_tables,
  } );
  return;
}

sub _define_column {
  my( $columns, $prop, $p_def ) = @_;

  $p_def = { 'type' => $p_def } unless ref $p_def;
  ( my $hr_col_name = ucfirst $prop ) =~ s{_}{ }mxsg;
  if( $p_def->{'type'} eq 'uid' ) {
    unshift @{$columns}, sprintf '%s int unsigned not null auto_increment primary key', $prop;
    return;
  }
  my $coltype = exists $EL_MAP{$p_def->{'type'}} ? $EL_MAP{$p_def->{'type'}}[1] : 'varchar(255)';

  $coltype = "varchar($p_def->{'length'})" if $coltype =~ m{^varchar}mxs && $p_def->{'length'};

  if( $p_def->{'type'} eq 'enum' ) {
    $coltype = sprintf q(enum( %s ) not null default '%s'),
      ( join q(, ), map { sprintf q('%s'), $_->[0] } @{ $p_def->{'values'}||[] } ),
      $p_def->{'default'}||q();
  } elsif( $p_def->{'type'} eq 'boolean' ) {
    $coltype .= sprintf q( not null default '%s'), exists $p_def->{'default'} ? $p_def->{'default'} : 'no';
  }
  push @{$columns}, sprintf '%s %s', $prop, $coltype;
  if( exists $p_def->{'unique'} && $p_def->{'unique'} ) {
    push @{$columns}, sprintf '  unique un_%s (%s)', $prop, $prop;
  }
  return;
}

sub _audit_columns {
  #@params (hashref) audit_defn
  ## audit hash ref with keys: user_id/user, datetime, ip, useragent, and
  ## values: update/create/both
  ##
  ## e.g. {qw(user_id both ip create useragent create datetime both)}
  my $audit_defn = shift;
  my @cols;
  if( exists $audit_defn->{'user_id'} ) {
    push @cols, 'created_by_id int unsigned not null',      '  index (created_by_id)'     if $audit_defn->{'user_id'}   ne 'update';
    push @cols, 'updated_by_id int unsigned not null',      '  index (updated_by_id)'     if $audit_defn->{'user_id'}   ne 'create';
  }
  if( exists $audit_defn->{'user'} ) {
    push @cols, 'created_by varchar(128) not null',         '  index (created_by)'        if $audit_defn->{'user'}      ne 'update';
    push @cols, 'updated_by varchar(128) not null',         '  index (updated_by)'        if $audit_defn->{'user'}      ne 'create';
  }
  if( exists $audit_defn->{'datetime'} ) {
    push @cols, 'created_at timestamp not null default CURRENT_TIMESTAMP',
                                                            '  index (created_at)'        if $audit_defn->{'datetime'}  ne 'update';
    push @cols, 'updated_at timestamp not null',            '  index (updated_at)'        if $audit_defn->{'datetime'}  ne 'create';
  }
  if( exists $audit_defn->{'ip'} ) {
    push @cols, 'created_ip varchar(64) not null',          '  index (created_ip)'        if $audit_defn->{'ip'}        ne 'update';
    push @cols, 'updated_ip varchar(64) not null',          '  index (updated_ip)'        if $audit_defn->{'ip'}        ne 'create';
  }
  if( exists $audit_defn->{'useragent'} ) {
    push @cols, 'created_useragent varchar(511) not null',  '  index (created_useragent)' if $audit_defn->{'useragent'} ne 'update';
    push @cols, 'updated_useragent varchar(511) not null',  '  index (updated_useragent)' if $audit_defn->{'useragent'} ne 'create';
  }
  return @cols;
}

########################################################################
##+------------------------------------------------------------------+##
##| SUPPORT METHODS                                                  |##
##+------------------------------------------------------------------+##
##| * _get_templates                                                 |##
##| * _perl_boilerplate                                              |##
##| * _write_file                                                    |##
##| * _die_with_docs                                                 |##
##+------------------------------------------------------------------+##
########################################################################

sub _get_templates {
  my $t = {};
  my $key;
  while(<DATA>) {
    if(m{\A>>>>>>>>>>>>>>>>>>>>>>>>(\S+)}mxs) {
      $key = $1;
      $t->{$key} = q();
    } else {
      $t->{$key}.=$_;
    }
  }
  return $t;
}

sub _perl_boilerplate {
  my $ui   = user_info();
  ## no critic (InterpolationOfMetachars)
  (my $t = q(## Author         : %1$s <%2$s>
## Maintainer     : %1$s <%2$s>
## Created        : %3$s

## Last commit by : _Author_
## Last modified  : _Date_
## Revision       : _Revision_
## Repository URL : _HeadURL_

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');) ) =~ s{_}{\$}mxsg;
  return sprintf $t,
    $ui->{'name'},
    $ui->{'username'}.q(@).$mod->mail_domain,
    $rt->time_str( '%o %h %Y', time );
  ## use critic
}

sub _write_heading {
  my $caption = shift;
  return if $quiet > 1;
  warn "\n   * $caption\n";
  return;
}

sub _write_file {
  my( $fn, $name, $contents ) = @_;
  warn "     * $fn\n" if $quiet <= 1;
  (my $dir = $fn) =~ s{/[^/]+\Z}{}mxs;
  my $tmpl = $templates->{$name};
  make_path( $dir ) unless -e $dir;

  $contents        ||={};
  $contents->{'ns' } = $ns;
  $contents->{'_ns'} = $_ns;
  $contents->{'bp' } = $bp;

  $tmpl =~ s{\[\[(\w+)\]\]}{$contents->{$1}||"====$1===="}mxseg;
  $tmpl =~ s{[ ]+$}{}mxsg;
  $tmpl =~ s{$act_map_from}{$act_map_to}mxosg if defined $act_map_to;

  if( open my $fh, q(>), $fn ) {
    print {$fh} $tmpl;  ## no critic (RequireChecked)
    close $fh;          ## no critic (RequireChecked)
    return ;
  }
  return;
}

sub db_config_note {
  return if $quiet;
  ## no critic (Carping)
  warn sprintf '
========================================================================

  Database configuration:

   * Add the following to databases.yaml

  %s:
    name: %s
    pass: {password}
    user: {user}
    host: {host}
    port: 3306

========================================================================

', lc $_ns, $db_name || lc $_ns;
  ## use critic
  return;
}


sub _die_with_docs {
  my $err = shift;
  warn "** $err\n\n" if $err;
  die '------------------------------------------------------------------------
Purpose:
    to take an object module defined in Pagesmith::Support::{name_space}

Usage:
    utilities/create-stubs [-d db_name] [-q] [-v] [-f] {name_space}

Options:
    -d  (-db_name) string opt
    -a  (-act_map) string opt
    -q  (-quiet)          opt
    -v  (-verbose)        opt
    -f  (-force)          opt
------------------------------------------------------------------------
';
}

########################################################################
##+------------------------------------------------------------------+##
##| NOTE THAT THIS IS THE REAL __END__ OF THIS SCRIPT - WHAT FOLLOWS |##
##| ARE DOCUMENATION/SQL/PERL MODULETEMPLATES......                  |##
##+------------------------------------------------------------------+##
##|  * Pagesmith::Support::{NS}                                      |##
##|  * Pagesmith::Action::{NS}                                       |##
##|  * Pagesmith::Adaptor::{NS}                                      |##
##|  * Pagesmith::Component::{NS}                                    |##
##|  * Pagesmith::Component::{NS}::Navigation                        |##
##|  * Pagesmith::MyForm::{NS}                                       |##
##|  * Pagesmith::MyForm::{NS}::Admin                                |##
##|  * Pagesmith::Object::{NS}                                       |##
##|  * Pagesmith::Object::{NS}::{OT}                                 |##
##|  * Pagesmith::Adaptor::{NS}::{OT}                                |##
##|  * Pagesmith::Action::{NS}::Admin::{OT}                          |##
##|  * Pagesmith::MyForm::{NS}::Admin::{OT}                          |##
##|  * {ns}.docs                                                     |##
##|  * {ns}.sql                                                      |##
##+------------------------------------------------------------------+##
########################################################################

__END__
>>>>>>>>>>>>>>>>>>>>>>>>Support
package Pagesmith::Support::[[ns]];

[[bp]]

## Base class for actions/components in [[ns]] namespace

use base qw(Pagesmith::ObjectSupport);
use Pagesmith::Utils::ObjectCreator qw(bake);

bake();

1;
__END__

Purpose
-------

The purpose of the Pagesmith::Support::[[ns]] module is to
place methods which are to be shared between the following modules:

* Pagesmith::Action::[[ns]]
* Pagesmith::Component::[[ns]]

Common functionality can include:

* Default configuration for tables, two-cols etc
* Database adaptor calls
* Accessing configurations etc

Some default methods for these can be found in the
Pagesmith::ObjectSupport from which this module is derived:

  * adaptor( $type? ) -> gets an Adaptor of type Pagesmith::Adaptor::[[ns]]::$type
  * my_table          -> simple table definition for a table within the site
  * admin_table       -> simple table definition for an admin table (if different!)
  * me                -> user object (assumes the database being interfaced has a
                         User table keyed by "email"...

>>>>>>>>>>>>>>>>>>>>>>>>Action
package Pagesmith::Action::[[ns]];

## Base class for actions in [[ns]] namespace

[[bp]]

use base qw(Pagesmith::Action Pagesmith::Support::[[ns]]);

sub my_wrap {
  my ( $self, $title, @body ) = @_;
  return $self
    ->html
    ->set_navigation_path( '/my_path' )
    ->wrap_rhs(
      $title,
      $self->panel( '<h2>[[ns]]</h2>
                     <h3>'.$self->encode( $title ).'</h3>',
                    @body,
      ),
      '<% [[_ns]]_Navigation -ajax %>',
    )
    ->ok;
}

sub run {
  my $self = shift;
  return $self->my_wrap( '[[ns]] test',
    $self->panel( '<p>Base action file created successfully</p>' ),
  );
}

1;

__END__
Notes
-----

This is the generic Action code for all the code with objects in the
namespace "[[ns]]".

>>>>>>>>>>>>>>>>>>>>>>>>Adaptor
package Pagesmith::Adaptor::[[ns]];

## Base adaptor for objects in [[ns]] namespace

[[bp]]

use base qw(Pagesmith::Adaptor);
use Pagesmith::Utils::ObjectCreator qw(bake_base_adaptor);

bake_base_adaptor;

1;

__END__
Notes
-----

>>>>>>>>>>>>>>>>>>>>>>>>Component
package Pagesmith::Component::[[ns]];

## Base class for components in [[ns]] namespace

[[bp]]

use base qw(Pagesmith::Component Pagesmith::Support::[[ns]]);

1;

__END__
Notes
-----

This is the generic Component code for all the code with objects in the
namespace "[[ns]]".

>>>>>>>>>>>>>>>>>>>>>>>>Component-Navigation
package Pagesmith::Component::[[ns]]::Navigation;

## Navigation component to insert into pages - mainly to handle admin links!

[[bp]]

use base qw(Pagesmith::AjaxComponent Pagesmith::Component::[[ns]]);

sub usage {
#@params (self)
#@return (hashref)
## Returns a hashref of documentation of parameters and what the component does!
  my $self = shift;
  return {
    'parameters'  => 'NONE',
    'description' => 'Navigation component',
    'notes'       => [],
  };
}

sub execute {
  my $self = shift;
  return $self->panel(
    '<h3>Navigation</h3>',
    '<ul><li><a href="/action/[[_ns]]">Home</a></li></ul>',
  ).$self->admin_panel;
}

sub admin_panel {
  my $self = shift;
  return q() unless $self->me;
  my @links;
  [[admin_links]]
  return q() unless @links;
  return $self->links_panel( 'Admin panel', \@links );
}

1;

__END__
Notes
-----

>>>>>>>>>>>>>>>>>>>>>>>>MyForm
package Pagesmith::MyForm::[[ns]];

## Base class for all forms in "[[ns]]"

[[bp]]

use base qw(Pagesmith::MyForm Pagesmith::Support::[[ns]]);

sub render_extra {
  my $self = shift;
  return '<% [[_ns]]_Navigation -ajax %>';
}

1;

__END__
Notes
-----

This is the generic Form code for all the code with objects in the
namespace "[[ns]]".

>>>>>>>>>>>>>>>>>>>>>>>>MyForm-Admin
package Pagesmith::MyForm::[[ns]]::Admin;

## Base class for all "table admin" forms in "[[ns]]"

[[bp]]

use base qw(Pagesmith::MyForm::ObjectAdmin Pagesmith::MyForm::[[ns]]);

sub admin_init {
  my $self = shift;
  return $self
    ->set_navigation_path( '/mypath' )
    ->SUPER::admin_init;
}

1;

__END__

>>>>>>>>>>>>>>>>>>>>>>>>Object
package Pagesmith::Object::[[ns]];

## Base class for all objects in "[[ns]]"
[[bp]]

use base qw(Pagesmith::Object);

1;

__END__

Notes
=====

Base class for all objects in "[[ns]]"

>>>>>>>>>>>>>>>>>>>>>>>>type:Object
package Pagesmith::Object::[[ns]]::[[ot]];
## Class for [[ot]] objects in namespace [[ns]].

[[bp]]

use base qw(Pagesmith::Object::[[ns]]);
use Pagesmith::Utils::ObjectCreator qw(bake);

## Last bit - bake all remaining methods!
bake();

1;

__END__

Purpose
=======

Object classes are the basis of the Pagesmith OO abstraction layer

Notes
=====

What methods do I have available to me...!
------------------------------------------

This is an auto generated module. You can get a list of the auto
generated methods by calling the "auto generated"
__PACKAGE__->auto_methods or $obj->auto_methods!

Overriding methods
------------------

If you override an auto-generated method a version prefixed with
std_ will be generated which you can use within the package. e.g.

sub get_name {
  my $self = shift;
  my $name = $self->std_get_name;
  $name = 'Sir, '.$name;
  return $name;
}

>>>>>>>>>>>>>>>>>>>>>>>>type:Adaptor
package Pagesmith::Adaptor::[[ns]]::[[ot]];

## Adaptor for objects of type [[ot]] in namespace [[ns]]

[[bp]]

use base qw(Pagesmith::Adaptor::[[ns]]);
use Pagesmith::Utils::ObjectCreator qw(bake);

## Last bit - bake all remaining methods!
bake();

1;

__END__

Purpose
-------

Adaptor classes interface with databases as the basis of the Pagesmith OO abstraction layer

Notes
=====

What methods do I have available to me...!
------------------------------------------

This is an auto generated module. You can get a list of the auto
generated methods by calling the "auto generated"
__PACKAGE__->auto_methods or $obj->auto_methods!

Overriding methods
------------------

If you override an auto-generated method a version prefixed with
std_ will be generated which you can use within the package. e.g.

sub store {
  my( $self, $o ) = @_;
  warn 'Storing '.$o->get_code,"\n";
  return $self->std_store( $o );     ## Call the standard method!
}

>>>>>>>>>>>>>>>>>>>>>>>>type:Action-Admin
package Pagesmith::Action::[[ns]]::Admin::[[ot]];

## Admin table display for objects of type [[ot]] in
## namespace [[ns]]

[[bp]]

use base qw(Pagesmith::Action::[[ns]]);

sub run {
#@params (self)
## Display admin for table for [[ot]] in [[ns]]
  my $self = shift;

  return $self->login_required unless $self->user->logged_in;
  return $self->no_permission  unless $self->me && $self->me->is_[[at]];

  ## no critic (LongChainsOfMethodCalls)
  return $self->my_wrap( q([[ns]]'s [[ot]]),
    $self
      ->my_table
      ->add_columns(
        [[table_columns]]
      )
      ->add_data( @{$self->adaptor( '[[ot]]' )->fetch_all_[[cc_ot]]||[]} )
      ->render.
    $self->button_links( '/form/[[_ns]]_Admin_[[ot]]', 'Add' ),
  );
  ## use critic
}

1;

__END__
Notes
-----

>>>>>>>>>>>>>>>>>>>>>>>>type:MyForm-Admin
package Pagesmith::MyForm::[[ns]]::Admin::[[ot]];

## Admininstration form for objects of type [[ot]]
## in namespace [[ns]]

[[bp]]

use base qw(Pagesmith::MyForm::[[ns]]::Admin);

sub object_type {
#@return (string) the type of object (within the namespace!)
  return '[[ot]]';
}

sub entry_names {
#@return (string+) - an array of names - these are used in the create_object/update_object code

  return qw([[form_entries]]);
}

sub initialize_form {
  my $self = shift;

  $self->admin_init;

    [[form_elements]]

  $self->add_end_stages;
  return $self;
}

1;
__END__
Notes
-----
>>>>>>>>>>>>>>>>>>>>>>>>docs
Documentation for [[ns]] object/adaptor code
==============================================================================

The following are the auto-generated methods for the
created modules (Adaptors, Object, Model, Support)

[[docs]]

>>>>>>>>>>>>>>>>>>>>>>>>schema
--
-- This file contains the schema for object in the "[[ns]]"
-- name space
--
-- created from   : [[mod_file]]
--
-- created by     : [[user]]
-- maintained by  : [[user]]
-- created on     : [[dt]]
--
-- Last commit by : $Author$
-- Last modified  : $Date$
-- Revision       : $Revision$
-- Repository URL : $HeadURL$
--

drop database if exists [[dbname]];
create database [[dbname]];
use [[dbname]];

-- ------------------------------------------------------------------------ --
-- Tables representing objects...                                           --
-- ------------------------------------------------------------------------ --

[[obj_tables]]

-- ------------------------------------------------------------------------ --
-- Tables representing relationships between objects                        --
-- ------------------------------------------------------------------------ --
[[rel_tables]]

