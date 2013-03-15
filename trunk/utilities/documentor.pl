#!/usr/bin/perl

## Retrieve documentation from file

## Author         : js5
## Maintainer     : js5
## Created        : 2012-11-19
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Perl::Critic;
use Data::Dumper qw(Dumper);
use Getopt::Long qw(GetOptions);
use Time::HiRes qw(time);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR $PROGRAM_NAME $EVAL_ERROR);
use Date::Format qw(time2str);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use HTML::Entities qw(encode_entities);
use IO::File;
use List::MoreUtils qw(any);

use Const::Fast qw(const);
const my $MAX_LENGTH => 50;
my $ROOT_PATH;
BEGIN {
  $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME)));
}

use lib "$ROOT_PATH/lib";

use Pagesmith::Utils::Documentor::Package;
use Pagesmith::Utils::Documentor::File;
use Pagesmith::HTML::Tabs;
use Pagesmith::HTML::TwoCol;
use Pagesmith::HTML::Table;

my $t_init = time;
my $res = find_perl_dirs();
my $files = {};
foreach my $libpath (@{$res->{'paths'}}) {
  get_perl_files( $files, $libpath, q(), $libpath );
}
#print raw_dumper( $files );exit;
my $t = time;
STDERR->autoflush(1); ## no critic (ExplicitInclusion)
printf {*STDERR} "%-40s :      %7.3f\n", 'Got files', $t - $t_init;
my $cc = 0;
my $parsed_files = {};
my $module_cache = {};
my $root_docs = $ROOT_PATH.'/sites/apps.sanger.ac.uk/htdocs/docs/perl/';
foreach my $path ( sort keys %{$files} ) {
  my $c=0;
  ( my $root_file_name   = $res->{'map'}{$path} ) =~ s{/}{_}mxsg;
  foreach my $module ( sort keys %{$files->{$path}} ) {
    my $filename = $files->{$path}{$module};
    my $package_obj = get_details_file( $filename, $module );
       $package_obj->set_root_directory( $path );
    ( my $output_file_name = $package_obj->name )                          =~ s{::}{-}mxsg;
    $package_obj->set_doc_filename( sprintf '%s-%s.html', $root_file_name, $output_file_name );
    $parsed_files->{$filename} = $package_obj;
    $module_cache->{$package_obj->name} = $package_obj;
    $c++;
  }
  my $t_last = time;
  printf {*STDERR} "%-40s : %4d %7.3f\n", q(  ).$res->{'map'}{$path}, $c, $t_last - $t;
  $t = $t_last;
  $cc+=$c;
}
printf {*STDERR} "%-40s : %4d %7.3f\n", 'Parsed', $cc, $t - $t_init;

my @tree = (q(<ul id="navigation">));

foreach my $path ( sort keys %{$files} ) {
  my $c=0;
  push @tree, sprintf q(<li class="branch coll"><span style="font-weight:bold">%s</span><ul>), $res->{'map'}{$path};
  my @current_branch;
  foreach my $module ( sort keys %{$files->{$path}} ) {
    my $filename = $files->{$path}{$module};
    my $package_obj = $parsed_files->{$filename};
    write_docs_file( $root_docs.$package_obj->doc_filename, $package_obj );
    my @this_branch = split m{::}mxs, $module;
    if( $this_branch[0] eq 'Pagesmith' ) {
      shift @this_branch;
      unshift @this_branch, 'Pagesmith::'.shift @this_branch;
    }
    my @temp_branch = @this_branch;
    my $previous_node = pop @current_branch;
    my $node          = pop @temp_branch;
    while( @temp_branch && @current_branch ) {
      last if $current_branch[0] ne $temp_branch[0];
      shift @current_branch;
      shift @temp_branch;
    }
    foreach( @current_branch ) {
      push @tree, q(</ul></li>);
    }
    foreach( @temp_branch ) {
      push @tree, qq(<li class="branch coll"><span>$_</span><ul>);
    }
    push @tree, sprintf q(<li class="node"><a href="%s">%s</a></li>), $package_obj->doc_filename,$node;
    @current_branch = @this_branch;
    ## Now we have to push the entry into the tree!
    $c++;
  }
  foreach ( @current_branch ) {
    push @tree, q(</ul></li>);
  }
  my $t_last = time;
  printf {*STDERR} "%-40s : %4d %7.3f\n", q(  ).$res->{'map'}{$path}, $c, $t_last - $t;
  $t = $t_last;
}
push @tree, q(</ul>);
open my $fh, q(>), "$root_docs/inc/list.inc"; ## no critic (RequireChecked)
print {$fh} join qq(\n), @tree,q();           ## no critic (RequireChecked)
close $fh;                                    ## no critic (RequireChecked)
my $t_last = time;
printf {*STDERR} "%-40s :      %7.3f\n", 'Written', $t_last - $t;
printf {*STDERR} "%-40s :      %7.3f\n", 'OVERALL', $t_last - $t_init;
exit;

#print Dumper( get_details_file( '/www/js5/www-dev/sites/canapps.sanger.ac.uk/lib/Pagesmith/Support/Cancer/Cltracking/Lims/Plate/Dna.pm' ) );

sub find_perl_dirs {
  my $dir_root = $ROOT_PATH;
  my @lib_paths;
  my %dir_map;
  foreach ( qw(lib utilities) ) {
    push @lib_paths, "$dir_root/$_";
    $dir_map{"$dir_root/$_"} = $_;
  }
  my $dh;
  my @dirs;
  if( opendir $dh, "$dir_root/sites" ) {
    while ( defined (my $file = readdir $dh) ) {
      next if $file =~ m{\A[.]}mxs;
      push @dirs, [ "$dir_root/sites/$file", $file ];
    }
    closedir $dh;
  }
  if( opendir $dh, $dir_root ) {
    while ( defined (my $file = readdir $dh) ) {
      next if $file =~ m{\A[.]}mxs;
      push @dirs, [ "$dir_root/$file", $file ];
    }
    closedir $dh;
  }
  foreach my $a_ref ( sort { $a->[0] cmp $b->[0] } @dirs) {
    my $new_path = $a_ref->[0];
    my $file     = $a_ref->[1];
    foreach ( qw(lib utilities cgi perl) ) {
      if( -d $new_path && -d "$new_path/$_" ) {
        $dir_map{ "$new_path/$_" } = "$file/$_";
        push @lib_paths, "$new_path/$_";
      }
    }
  }
  return {(
    'paths' => \@lib_paths,
    'map'   => \%dir_map,
  )};
}

sub get_perl_files {
  my( $l_files, $path, $prefix, $root ) = @_;
  return unless -e $path && -d $path && -r $path;
  my $dh;
  return unless opendir $dh, $path;
  while ( defined (my $file = readdir $dh) ) {
    my $new_path = "$path/$file";
    next if $file =~ m{^[.]}mxs;
    next if $file =~ m{([.]b[ac]k|~)$}mxs;
    if( -f $new_path ) { ## no critic (Filetest_f)
      if( $file =~ m{^(.*)[.]p[ml]$}mxs ) { ## .pl || .pm files
        $l_files->{$root}{ "$prefix$1" } = $new_path;
      } else { ## Check other files to see if have #! line...
        next unless open my $in_fh, '<', $new_path;
        my $first_line = <$in_fh>;
        close $in_fh; ## no critic (RequireChecked)
        $l_files->{$root}{ "$prefix$file" } = $new_path if $first_line && $first_line =~ m{^\#!.*perl}mxs;
      }
    } elsif( -d $new_path ) {
      get_perl_files( $l_files, $new_path, "$prefix$file".q(::), $root );
    }
  }
  return;
}

## no critic (ExcessComplexity)
sub get_details_file {
  my( $filename, $module_name ) = @_;
  my $file_object = Pagesmith::Utils::Documentor::File->new( $filename );
  my $package     = Pagesmith::Utils::Documentor::Package->new( $file_object );
  $package->set_name( $module_name );
  $file_object->open_file;

  my $start_block = 1;
  my $current_sub;
  my $flag;

  while( my $line = $file_object->next_line ) {
    ## no critic (CascadingIfElse ComplexRegexes)
    if( $line =~ m{\A[#]!}mxs ) {
      next;
    }
    if( $start_block ) {
      if( $line =~ m{package\s+([\w:]+)}mxs ) {
        $package->set_name( $1 );
      } elsif( $line =~ m{[#]{2}\s*(Author|Maintainer|Created|Last[ ]commit[ ]by|Last[ ]modified|Revision|Repository[ ]URL)\s*:\s*(.*)}mxs ) {
        $package->set_rcs_keyword( $1, $2 );
      } elsif( $line =~ m{[#]{2}\s*(.*)}mxs ) {
        $package->push_description( $1 );
      } elsif( $line =~ m{\S}mxs) {
        $start_block = 0;
      }
    }
    ## use critic

    if( $line =~ m{\A__(?:END|DATA)__}mxs ) {
      ## We now are at the end of the file - grab extra markup!
      $file_object->empty_line;
      while( my $end_line = $file_object->next_line ) {
        $package->push_notes( $end_line );
        $file_object->empty_line;
      }
      last;
    }
    if($line =~ m{\Asub\s+(\S+)}mxs ) {
      ## Start of sub
      $current_sub  = $package->new_method( $1 );
      $current_sub->set_start( $file_object->line_count );
      $start_block  = 0;
      $flag         = 1;
      next;
    }
    if($line =~ m/\A}/mxs) {
     ## End of sub
      next unless $current_sub;
      $current_sub->set_end( $file_object->line_count );
      $current_sub = undef;
      next;
    }
    unless( $current_sub ) {
      # Use base...
      if( $line =~ m{\A\s*use\s+base\s+q[qw]?[(]\s*(.*?)\s*[)]}mxs ||
        $line =~ m{\A\s*use\s+base\s+["']\s*(.*?)\s*["']}mxs ) {
        $package->set_parents( split m{\s+}mxs, $1 );
        next;
      }
      # Now we do the other use lines... - use
      if( $line =~ m{\A\s*use\s+([\w:]+)\s*;}mxs ) {
        $package->push_use( $1 );
        next;
      }
      # use with with import!
      if( $line =~ m{\A\s*use\s+([\w:]+)\s+q[qw]?[(]\s*(.*?)\s*[)]}mxs ||
        $line =~ m{\A\s*use\s+([\w:]+)\s+["']\s*(.*?)\s*["']}mxs ) {
        $package->push_use( $1, split m{\s+}mxs, $2);
        next;
      }
      ## no critic (ComplexRegexes)
      if( $line =~ m{\A\s*(?:Readonly|Const::Fast)\s+my\s+([\$]\w+)\s*=>\s*(.*?);?\Z}mxs ) {
        $package->push_constant( $1, $2 );
        next;
      }
      if( $line =~ m{\A\s*my\s+([\$]\w+)\s*=\s*(.*?);?\Z}mxs ) {
        $package->push_package_variable( $1, $2 );
        next;
      }
      if( $line =~ m{\A\s*my\s+([\$]\w+);\Z}mxs ) {
        $package->push_package_variable( $1 );
      }
      next;
      ## use critic
    }
    if( $line =~ m{\A[#]@class\s*(\S+)}mxs ) {
      $current_sub->set_class( $1 );
      $file_object->empty_line;
      next;
    }
    if( $line =~ m{\A[#]@params\s*(.*)}mxs ) {
      $current_sub->set_documented;
      my $params = $1;
      while( $params =~ s{\A[(](\S+?)(?:\s+(.*?)\s*)?[)]([*+?]?)(\s.*|)\Z}{$4}mxs ) {
        my( $description, $type, $optional, $name ) = (q(),$1,$3,$2);
        if( $name && $name =~ s{\s+-\s+($.*)\Z}{}mxs ) {
          $description = $1;
        }
        $current_sub->push_parameter( $type, $name, $optional, $description );
        $params =~ s{\A\s+}{}mxs;
      }
      $file_object->empty_line;
      next;
    }
    if( $line =~ m{\A[#]@param\s*[(](\S+?)[)]([*+?]?)(?:\s+(.*))?\Z}mxs ) {
      my( $description, $type, $optional, $name ) = (q(),$1,$2,$3);
      if( $name && $name =~ s{\s+-\s+($.*)\Z}{}mxs ) {
        $description = $1;
      }
      $current_sub->set_documented;
      $current_sub->push_parameter( $type, $name, $optional, $description );
      $file_object->empty_line;
      next;
    }

    if( $line =~ m{\A[#]@return\s*[(](\S+?)[)](?:\s+(.*))?\Z}mxs ) {
      $current_sub->set_documented;
      $current_sub->set_return_type( $1 );
      $current_sub->set_return_desc( $2 );
      $file_object->empty_line;
      next;
    }
    if( $line =~ m{\A[#]{2}\s*(.*)}mxs && $flag ) {
      $current_sub->set_documented;
      my $note = $1;
      if( $note !~ m{\A\w}mxs ) {
        $flag = 2;
      }
      if( $flag == 1 ) {
        $current_sub->push_description( $note );
      } else {
        $current_sub->push_notes( $note );
      }
      $file_object->empty_line;
      next;
    }
    $flag = 0;

    ## Now we don't have any parameters so look for the first "my" line!
    if( !$current_sub->number_parameters && ($line =~ m{\A\s*my\s*[(]\s*(.*?)\s*[)]\s*=\s*@_}mxs) ) {
      my @params = split m{\s*,\s*}mxs, $1;
      foreach ( @params ) {
        if( m{([\$%@])(\w+)}mxs ) {
          $current_sub->push_parameter( $2 eq 'self'|| $2 eq 'class' ? $2 : q(), $1 eq q($) ? q() : q(*), $2 );
        } else {
          $current_sub->push_parameter( $_, q(), q() );
        }
      }
      next;
    }
    if( !$current_sub->number_parameters && ($line =~ m{\A\s*my\s+[\$](\w+)\s*=\s*shift}mxs) ) {
      $current_sub->push_parameter( $1 eq 'self'|| $1 eq 'class' ? $1 : q(), q(), $1 );
    }
    if( !$current_sub->number_parameters && ($line =~ m{\A\s*return\s+shift->}mxs) ) {
      $current_sub->push_parameter( 'self', q(), q(self) );
    }
  }
  $file_object->close_file;
  return $package;
}
## use critic

sub raw_dumper {
  my( $data_to_dump, $name_of_data ) = @_;
  return Data::Dumper->new( [ $data_to_dump ], [ $name_of_data ] )->Sortkeys(1)->Indent(1)->Terse(1)->Dump();
}

sub write_docs_file {
  my( $filename, $package_obj ) = @_;
  my $tabs = Pagesmith::HTML::Tabs->new;
  $tabs->add_tab( 'details', 'Details',            generate_details( $package_obj ) );
  $tabs->add_tab( 'summary', 'Methods',            generate_summary( $package_obj ) );
  if( $package_obj->parents ) {
    ( my $fn = $package_obj->doc_filename ) =~ s{[.]html\Z}{.inc}msx;
    ( my $output_filename = $filename     ) =~ s{[^/]+\Z}{inc/methods/$fn}mxs;
    $tabs->add_tab( 'summary_full', 'All methods', sprintf '<%% File -ajax /docs/perl/inc/methods/%s %%>', $fn );
    open my $inc_fh, q(>), $output_filename;               ## no critic (RequireChecked)
    print {$inc_fh} generate_summary_full( $package_obj ); ## no critic (RequireChecked)
    close $inc_fh;                                         ## no critic (RequireChecked)
  }
  $tabs->add_tab( 'docs',    'Documented methods', generate_methods( $package_obj ) );
  $tabs->add_tab( 'general', 'General notes',      generate_notes(   $package_obj ) );
  $tabs->add_tab( 'source',  'Source',             generate_source(  $package_obj ) );
  if( $package_obj->name =~ m{\APagesmith::Component::(.*)\Z}mxs ) {
    $tabs->add_tab( 'Usage',  'Usage',             sprintf '<%% Usage %s %%>', $1 );
  }
  ## no critic (ImplicitNewlines)
  my $markup = sprintf q(<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <title>Package: %s</title>
  <%% CssFile /docs/perl/css/documentor.css /core/css/beta/nav.css %%>
  <%% JsFile  /docs/perl/js/documentor.js   /core/js/beta/nav.js   %%>
</head>
<body id="documentor">
  <div id="main">
    <div class="panel">
      <h2><span class="toggle-width"><=></span>%s</h2>
      %s
    </div>
  </div>
  <div id="rhs">
    <div class="panel"><h3>Files</h3>
    <%% File inc/list.inc %%>
    </div>
  </div>
</body>
</html>
),
    $package_obj->name,
    $package_obj->name,
    $tabs->render;
  ## use critic
  open my $fh, q(>), $filename; ## no critic (RequireChecked)
  print {$fh} $markup;          ## no critic (RequireChecked)
  close $fh;                    ## no critic (RequireChecked)
  return;
}

sub generate_source {
  my $package_obj = shift;
  my $short_filename = substr $package_obj->file->name, length $ROOT_PATH;
  return sprintf '<%% Markedup -format perl -number line %s %%>',
    $short_filename;
}

sub isa_list {
  my ( $package_obj, $isa_list ) = @_;
  if( $package_obj->parents ) {
    foreach my $pg ( $package_obj->parents ) {
      next if any { $pg eq $_ } @{$isa_list};
      push @{$isa_list}, $pg;
      next unless exists $module_cache->{$pg};
      isa_list( $module_cache->{$pg}, $isa_list );
    }
  }
  return;
}

sub generate_details {
  my $package_obj = shift;
  my $html = $package_obj->format_description;
  my $twocol = Pagesmith::HTML::TwoCol->new;
     $twocol->add_entry( 'File', $package_obj->file->name );
  foreach my $k ('Author','Created','Maintainer','Last commit by','Last modified','Repository URL') {
    $twocol->add_entry( $k, $package_obj->rcs_keyword( $k ) || q(-) );
  }
  my $list_of_packages = [];
  if( $package_obj->parents ) {
    isa_list( $package_obj, $list_of_packages );
    my %real_parents = map { ($_=>1) } $package_obj->parents;
    foreach my $package ( @{$list_of_packages} ) {
      my $name = $package;
      $name = "<em>$package</em>" unless exists $real_parents{$package};
      if( exists $module_cache->{$package}) {
        $name = sprintf '<a href="%s">%s</a>', $module_cache->{$package}->doc_filename, $name;
      }
      $twocol->add_entry( 'Parent(s)', $name )
    }
  }
  my %used = $package_obj->used_packages;
  if( keys %used ) {
    my $used = Pagesmith::HTML::TwoCol->new({'class'=>'evenwidth'});
    foreach my $package ( sort keys %used ) {
      my @methods = @{$used{$package}||[]};
      if( exists $module_cache->{$package}) {
        $package = sprintf '<a href="%s">%s</a>', $module_cache->{$package}->doc_filename, $package;
      }
      if( @methods ) {
        $used->add_entry( $package, $_ ) foreach @methods;
      } else {
        $used->add_entry( $package, q(-) );
      }
    }
    $twocol->add_entry( 'Used', $used->render );
  }
  my %const = $package_obj->constants;
  if( keys %const ) {
    my $const = Pagesmith::HTML::TwoCol->new({'class'=>'twothird'});
    foreach my $name ( sort keys %const ) {
      $const->add_entry( $name, encode_entities($const{$name}) );
    }
    $twocol->add_entry( 'Constant', $const->render );
  }
  my %package_variables = $package_obj->package_variables;
  if( keys %package_variables ) {
    my $pv = Pagesmith::HTML::TwoCol->new({'class'=>'twothird'});
    foreach my $name ( sort keys %package_variables ) {
      $pv->add_entry( $name, encode_entities($package_variables{$name}) );
    }
    $twocol->add_entry( 'Package variables', $pv->render );
  }
  $html .= $twocol->render;
  return $html;
}

sub generate_summary {
  my $package_obj = shift;
  ## no critic (LongChainsOfMethodCalls)
  my @methods = $package_obj->methods;
  my $table = Pagesmith::HTML::Table->new
    ->make_sortable
    ->add_class( 'before narrow-sorted' )
    ->set_filter
    ->set_export( [qw(txt csv xls)] )
    ->set_pagination( ['all'] )
    ->add_columns(
      { 'key' => q(#), },
      { 'key' => 'name',                        'label' => 'Name',
        'link' => [ [ 'class=change-tab #method_[[h:name]]', 'exact', 'is_documented', 'Y' ] ],
      },
      { 'key' => 'is_documented',               'label' => 'Doc?',        'align'  => 'c' },
      { 'key' => 'is_method',                   'label' => 'Meth?',       'align'  => 'c' },
      { 'key' => 'format_parameters_short',     'label' => 'Parameters',  'format' => 'r' },
      { 'key' => 'format_return_short',         'label' => 'Return',      'format' => 'r' },
      { 'key' => 'format_description',          'label' => 'Description', 'format' => 'r' },
      { 'key' => 'location',                    'label' => 'Location',
        'link' => '#line_[[d:start]]',
        'template' => '[[d:start]]-[[d:end]]', 'align' => 'c' },
    )
    ->add_data( @methods );
  ## use critic
  return $table->render;
}

sub generate_summary_full {
  my $package_obj = shift;
  ## no critic (LongChainsOfMethodCalls)
  my @methods = $package_obj->methods;
  my $list_of_packages = [];
  my %seen_methods = map { ( $_->name => 1 ) } @methods;
  isa_list( $package_obj, $list_of_packages );
  my $hidden = {};
  foreach my $par ( @{$list_of_packages} ) {
    next unless exists $module_cache->{$par};
    foreach my $method_obj ( $module_cache->{$par}->methods ) {
      if( $seen_methods{ $method_obj->name } ) {
        $hidden->{$par}{$method_obj->name}=1;
      } else {
        $seen_methods{ $method_obj->name }=1;
      }
      push @methods, $method_obj;
    }
  }
  my $table = Pagesmith::HTML::Table->new
    ->make_sortable
    ->add_class( 'before narrow-sorted' )
    ->set_filter
    ->set_export( [qw(txt csv xls)] )
    ->set_pagination( [qw(10 20 50 100 all)], q(20) )
    ->make_scrollable
    ->set_current_row_class( sub {
      return exists $hidden->{ $_[0]->package_name }{ $_[0]->name } ? 'parent struck'
           : $_[0]->package_name ne $package_obj->name              ? 'parent'
           :                                                     q()
           ;
    })
    ->add_columns(
      { 'key' => q(#), },
      { 'key' => 'name',                        'label' => 'Name',
        'link' => sub {
           return q() unless $_[0]->is_documented;
           return sprintf '%s#method_%s',
             $_[0]->package_name eq $package_obj->name ? q() : 'rel=external '.$module_cache->{$_[0]->package_name}->doc_filename,
             $_[0]->name;
        } },
        #'link' => [ [ 'class=change-tab #method_[[h:name]]', 'exact', 'is_documented', 'Y' ] ] },
      { 'key' => 'is_documented',               'label' => 'Doc?',        'align'  => 'c' },
      { 'key' => 'is_method',                   'label' => 'Meth?',       'align'  => 'c' },
      { 'key' => 'format_parameters_short',     'label' => 'Parameters',  'format' => 'r' },
      { 'key' => 'format_return_short',         'label' => 'Return',      'format' => 'r' },
      { 'key' => 'format_description',          'label' => 'Description', 'format' => 'r' },
      { 'key' => 'location',                    'label' => 'Location',
        'link' => sub {
           return sprintf '%s#line_%d',
             $_[0]->package_name eq $package_obj->name ? q() : 'rel=external '.$module_cache->{$_[0]->package_name}->doc_filename,
             $_[0]->start;
        },
        'template' => '[[d:start]]-[[d:end]]', 'align' => 'c' },
      { 'key' => 'package',                     'label' => 'Package'                      },
    )
    ->add_data( @methods );
  ## use critic
  return $table->render;
}

sub generate_methods {
  my $package_obj = shift;
  my @methods = $package_obj->documented_methods;
  return '<p>No documented methods</p>' unless @methods;
  my $fake_tabs = Pagesmith::HTML::Tabs->new({'fake'=>1});
  foreach (@methods) {
    my $meth = Pagesmith::HTML::TwoCol->new;
    my $notes = $_->format_notes;
    $meth->add_entry( 'Type',       $_->method_desc );
    $meth->add_entry( 'Parameters', $_->format_parameters );
    $meth->add_entry( 'Returns',    $_->format_return );
    $meth->add_entry( 'Notes', $notes ) if $notes;
    ## no critic (ImplicitNewlines)
    $fake_tabs->add_tab(
      'method_'.$_->name, $_->name,
      $_->format_description.
      $meth->render.
      sprintf '<h4>Code</h4><div class="collapsible collapsed">
     <p class="head">Lines %d - %d <span class="show"> [show source code]</span><span class="hide"> [hide source code]</span>
     <pre class="code">%s</pre></div>
     <p><a href="#line_%s">View in main source code</a></p>', $_->start, $_->end, $_->code, $_->start,
    );
    ## use critic
  }
  return sprintf '<div class="sub_nav left"><h4>Methods</h4>%s</div><div class="sub_data">%s</div>',
    $fake_tabs->render_ul_block, $fake_tabs->render_div_block;
}

sub generate_notes {
  my $package_obj = shift;
  return $package_obj->format_notes;
}
__END__
