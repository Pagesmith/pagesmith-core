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
  'string'    => [ 'Text',        'text'                ],
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
### ---------------------------------------------------------------------------------------

my $quiet   = 0;
my $verbose = 0;
my $force   = 0;

GetOptions(
  'quite'        => \$quiet,
  'verbose+'     => \$verbose,
  'force'        => \$force,
);

### Get namespace
### and get support module for name space
###  * check it exists
###  * check we can use it
###  * check it has a bake_model call in it
### ---------------------------------------------------------------------------------------

run_docs( 'You must specify a name space' ) unless @ARGV;
my $ns = shift @ARGV;

run_docs( 'Not a valid perl name space' ) unless $ns =~ m{\A[[:upper:]]\w*(::[[:upper:]]\w*)*\Z}mxs;

(my $_ns      = $ns )=~s{::}{_}mxsg;          ## For use in Component/Actions...
 my $rt       = Pagesmith::Root->new;         ## Root module so we can dynamic ic
 my $sup      = "Pagesmith::Support::$ns";
(my $mod_file = "$sup.pm" ) =~ s{::}{/}mxsg;

warn "========================================================================
# $sup
========================================================================

";

unless( $rt->dynamic_use( $sup ) ) { ## Check to see if we can include it!
  my $msg = $rt->dynamic_use_failure( $sup );
  die "\n" if index $msg, "Can't locate $mod_file in \@INC (\@INC";
  die "No $sup module in file path\n\n";
}

die "Module $sup doesn't call bake_model\n\n" unless $sup->can( 'auto_methods' );

### Get the boilerplate code, code templates & also the lib path the Support module
### is stored in....
### ---------------------------------------------------------------------------------------

( my $library_root = $INC{$mod_file} ) =~ s{Pagesmith/Support/.*}{}mxs;
my $bp        = _boilerplate( $rt, $sup );
my $templates = _get_templates();


### Finally generate files if required
###  * Main "core" adaptors
###  * type objects & adaptors
###  * relationship adaptors (*)
###  * admin action (R/D - table/remove) & admin form (C/U - add/update)
###  * create a draft SQL schema for object models...
### ---------------------------------------------------------------------------------------

generate_core_modules();
create_adaptors_and_objects();
create_admin_methods();
create_schema();

exit;

sub run_docs {
  my $err = shift;
  warn "** $err\n\n" if $err;
  die '------------------------------------------------------------------------
Purpose:
    to take an object module defined in Pagesmith::Support::{name_space}

Usage:
    utilities/create-stubs [-q] [-v] [-f] {name_space}

Options:
    -q  (-quiet)       opt
    -v  (-verbose)     opt
    -f  (-force)       opt
------------------------------------------------------------------------
';
}

###########################################################################################
### Now code which generates the files...                                               ###
###########################################################################################

sub generate_core_modules {
  foreach my $stub_type (qw( Action Adaptor Component Component-Navigation MyForm MyForm-Admin Object) ) {
    my @parts = split m{-}mxs, $stub_type;
    my $module_name = @parts > 1 ? "Pagesmith::$parts[0]::$ns"."::$parts[1]" : "Pagesmith::$parts[0]::$ns";
    ( my $module_file = "$library_root/$module_name.pm" ) =~ s{::}{/}mxsg;
    if( !$force && -e $module_file ) {
      warn "Skipping file.... $module_file\n";
      next;
    }
    _write_file( $module_file, $stub_type, { } );
  }
  return;
}

sub create_adaptors_and_objects {
  foreach my $obj_type ( $sup->my_obj_types ) {
    ## Create adaptor, object and admin interfaces!
    foreach my $type ( qw(Adaptor Object) ) {
      my $module_name = join q(::), 'Pagesmith', $type, $ns, $obj_type;
      ( my $module_file = "$library_root/$module_name.pm" ) =~ s{::}{/}mxsg;
      if( !$force && -e $module_file ) {
        warn "Skipping file.... $module_file\n";
        next;
      }
      _write_file( $module_file, "type:$type", { 'ot' => $obj_type } );
    }
  }
  if($verbose) {
    foreach my $obj_type ( $sup->my_obj_types ) {
      ## Create adaptor, object and admin interfaces!
      foreach my $type ( qw(Adaptor Object) ) {
        my $module_name = join q(::), 'Pagesmith', $type, $ns, $obj_type;
        $rt->dynamic_use( $module_name );
        printf "%s\n\n",
          join "\n  * ", "$module_name methods:", $module_name->auto_methods;
      }
    }
  }
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

sub create_schema {
  ## Get schema filename and check to see if we need to create it!
  my $schema_file = (substr $library_root, 0, $LEN_LIB). lc "sql/$_ns.sql";
  if( !$force && -e $schema_file ) {
    warn "Skipping file.... $schema_file\n";
    return;
  }
  my @tables;
  my $defn_method = $sup.'::my_defn';

  ## For each object
  foreach my $obj_type ( $sup->my_obj_types ) {
    no strict 'refs'; ## no critic (NoStrict)
    my $definition = &{$defn_method}( $obj_type );
    use strict;
    my @columns;

    foreach my $prop ( sort keys %{$definition->{'properties'}} ) {
      _define_column( \@columns, $prop, $definition->{'properties'}{$prop} );
    }
    foreach my $prop ( sort keys %{$definition->{'related'}||{}} ) {
      my $p_def = $definition->{'related'}{$prop};
      next unless exists $p_def->{'to'};
      push @columns, sprintf '%s int unsigned not null', $prop;
      push @columns, sprintf '  index fk_%s (%s)', $prop, $prop;
    }
    push @tables, sprintf '
-- Table %s - stores details of %s::%s objects

drop table if exists %s;
create table %s (
  %s
);
', lc $obj_type,  $ns, $obj_type,  lc $obj_type, lc $obj_type, join qq(,\n  ), @columns;
  }
  foreach my $rel_type ( $sup->my_rel_types ) {
    my @columns;
    no strict 'refs'; ## no critic (NoStrict)
    my $definition = &{$defn_method}( $rel_type );
    use strict;
    my @unique;
    foreach my $otype ( sort keys %{$definition->{'objects'}} ) {
      foreach my $col_name ( sort @{$definition->{'objects'}{$otype}} ) {
        push @columns, sprintf '%s int unsigned not null', $col_name;
        push @columns, sprintf '  index fk_%s (%s)', $col_name, $col_name;
        push @unique, $col_name;
      }
    }
    push @columns, sprintf '  index un_%s (%s)', lc $rel_type, join q(, ), @unique;
    foreach my $prop ( sort keys %{$definition->{'additional'}} ) {
      _define_column( \@columns, $prop, $definition->{'additional'}{$prop} );
    }
    push @tables, sprintf '
-- Table %s - stores details of %s::%s relationships

drop table if exists %s;
create table %s (
  %s
);
', lc $rel_type,  $ns, $rel_type, lc $rel_type, lc $rel_type, join qq(,\n  ), @columns;
    #print $rt->raw_dumper( [ $rel_type, ] );
  }
  my $ui = user_info();
  _write_file( $schema_file, 'schema', {
    'sup_file' => $sup,
    'user'     => "$ui->{'name'} <$ui->{'username'}\@".$sup->mail_domain.q(>),
    'dt'       => $rt->time_str( '%o %h %Y', time ),
    'dbname'   => lc $_ns,
    'tabledef' => join q(), @tables,
  } );
  return;
}

sub form_add {
  my( $el_type, $prop ) = @_;
  $el_type = sprintf q(%-24s),"'$el_type',";
  return sprintf q[$self->add(           %s '%s' )], $el_type, $prop; ## no critic (InterpolationOfMetachars)
}

## no critic (ExcessComplexity)
sub create_admin_methods {
  foreach my $obj_type ( $sup->my_obj_types ) {
    my $defn_method = $sup.'::my_defn';

    no strict 'refs'; ## no critic (NoStrict)
    my $definition = &{$defn_method}( $obj_type );
    use strict;

    my @table_columns;
    my @table_extra;
    my @form_entries;
    my @form_extra    = (q());
    my @form_elements = (q());
    foreach my $prop ( sort keys %{$definition->{'properties'}} ) {
      my $p_def = $definition->{'properties'}{$prop};
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
    foreach my $rel ( sort keys %{$definition->{'related'}} ) {
      my $r_def = $definition->{'related'}{$rel};
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
      my @cols = sort values %{$r_def->{'derived'}||{}};
      @cols = (lc $r_def->{'to'}.'_id') unless @cols;
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
      ( my $module_file = "$library_root/$module_name.pm" ) =~ s{::}{/}mxsg;
      if( !$force && -e $module_file ) {
        warn "Skipping file.... $module_file\n";
        next;
      }
      my $conf = {
        'ot' => $obj_type,
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

###########################################################################################
### Support methods...........................                                          ###
###########################################################################################

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

sub _boilerplate {
  my $ui   = user_info();
  ## no critic (InterpolationOfMetachars)
  return sprintf q(## Author         : %1$s <%2$s>
## Maintainer     : %1$s <%2$s>
## Created        : %3$s

## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');),
  $ui->{'name'},
  $ui->{'username'}.q(@).$sup->mail_domain,
  $rt->time_str( '%o %h %Y', time );
  ## use critic
}

sub _write_file {
  my( $fn, $name, $contents ) = @_;
  warn "Creating file.... $fn\n" unless $quiet;
  (my $dir = $fn) =~ s{/[^/]+\Z}{}mxs;
  my $tmpl = $templates->{$name};
  make_path( $dir ) unless -e $dir;

  $contents        ||={};
  $contents->{'ns' } = $ns;
  $contents->{'_ns'} = $_ns;
  $contents->{'bp' } = $bp;

  $tmpl =~ s{\[\[(\w+)\]\]}{$contents->{$1}||"====$1===="}mxseg;
  $tmpl =~ s{[ ]+$}{}mxsg;

  if( open my $fh, q(>), $fn ) {
    print {$fh} $tmpl;  ## no critic (RequireChecked)
    close $fh;          ## no critic (RequireChecked)
    return ;
  }
  return;
}

__END__
>>>>>>>>>>>>>>>>>>>>>>>>Action
package Pagesmith::Action::[[ns]];

## Base class for actions in [[ns]] namespace

[[bp]]

use base qw(Pagesmith::Action Pagesmith::Support::[[ns]])

sub my_wrap {
  my ( $self, $title, @body ) = @_;
  return $self
    ->html
    ->set_navigation_path( '/my_path' )
    ->wrap_rhs(
      $title,
      $self->panel( '<h2>my_title</h2>
                     <h3>'.$self->encode( $title ).'</h3>',
      @body ),
      '<% [[_ns]]_Navigation -ajax %>',
    )
    ->ok;
}

sub run {
  my $self = shift;
  return $self->my_wrap( '[[ns]] test', $self->panel( '<p>Base action file created successfully</p>' );
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

bake_base_adaptor();

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
  return $self->panel( '<h3>Navigation</h3>' );
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
use Pagesmith::Utils::ObjectCreator qw(bake_object);

## Last bit - bake all remaining methods!
bake_object;

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
use Pagesmith::Utils::ObjectCreator qw(bake_adaptor);

## Last bit - bake all remaining methods!
bake_adaptor;

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
  return $self->no_permission  unless $self->me && $self->me->is_superadmin;

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
>>>>>>>>>>>>>>>>>>>>>>>>schema
--
-- This file contains the schema for object in the "[[ns]]"
-- name space
--
-- created from   : [[sup_file]]
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
[[tabledef]]
