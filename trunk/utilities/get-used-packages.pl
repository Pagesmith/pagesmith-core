#!/usr/bin/perl

## Keeps a serve up to date - BUT not using keep uptodate - basically runs svn up on each repository

## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;
use feature qw(switch);

use version qw(qv); our $VERSION = qv('0.1.0');

use English        qw(-no_match_vars $PROGRAM_NAME $EVAL_ERROR);
use File::Basename qw(dirname);
use Cwd            qw(abs_path);
use Data::Dumper; ## no xcritic (DebuggingModules)
use File::Find     qw(find);
use LWP::UserAgent;
use IPC::Run3      qw(run3);

## Set up constants!
my @REQUIRED_BINARIES =qw(
  make gcc
  pngcrush jpegoptim advpng optipng qrencode
  java mysql
  multitail memcached mysqld
);

my %REQUIRED_BY_TYPE = (
  'debian' => [qw(alien php5 tidy)],
  'redhat' => [qw(php tidyp)],
);

my %OTHER_PACKAGES = (
  'debian' => [qw(php5-imagick php5-mysql php5-gd tomcat7
                  libevent-dev libssl-dev )],
  'redhat' => [qw(php-magickwand php-mysqlnd php-gd tomcat
                  openssl-devel libevent-devel)],
);

my $ignore_whats_installed = (@ARGV && $ARGV[0] eq '-i') ? 1 : 0;

my $CPAN_PACKAGES = 'http://www.cpan.org/modules/02packages.details.txt';
my $PACKAGE_PATH  = {
  'debian' => 'apt-get -q -q -q -y install',
  'redhat' => 'yum -q -y install',
  'cpan'   => 'cpan',
  'source' => '## MANUAL INSTALL:',
};
my $PRAGMAS       = { map { $_ => 1 } qw(strict warnings utf8 version feature integer lib vars) };
## get root path...
my $ROOT_PATH     = dirname(dirname(abs_path($PROGRAM_NAME)));
my $UTILS_PATH    = dirname($ROOT_PATH).'/utilities';

my $PACKMAN_TYPE  = -e '/usr/bin/dpkg' ? 'debian'
                  : -e '/usr/bin/rpm'  ? 'redhat'
                  :                      'source'
                  ;
my @MUNGED_INC    = get_munged_inc();
my @MUNGED_PATH   = get_munged_path();
## This bit of code will get the list of paths
## Both script and lib... if you wish to pick up other paths
## then this is the bit of code that you will need to extend

my @dirs = get_dirs();
my @lib_paths = grep { -d $_ } "$UTILS_PATH/lib", map { ( "$_/lib", "$_/ext-lib" ) } @dirs;
my @scr_paths = grep { -d $_ } $UTILS_PATH,       map { "$_/utilities"             } @dirs;

## Get details of scripts (this uses find so need a global variable!)
my @libs;
my $mod_list = {};

my ( $bin_info,    $bin_dupes    ) = get_binary_sources( @REQUIRED_BINARIES );
get_apache_sources();
dump_bin_structures( $bin_info, $bin_dupes );
dump_bin_install_scripts( $bin_info, $bin_dupes );

get_libs(      \@lib_paths   );
get_details(  'lib', @libs  );

## Get details of scripts (this uses find so need a global variable!)
my @scrs;
get_scripts(  \@scr_paths   );
get_details(  'scr', @scrs  );

my ($x_sources,$x_core,$x_non_core,$x_package_dupes,$x_inst_flag) = get_module_source();
dump_output($x_sources,$x_core,$x_non_core,$x_package_dupes);
dump_structures( $x_sources );
dump_install_scripts($x_sources,[ sort keys %{$x_non_core}],$x_package_dupes,$x_inst_flag);
## end of main!

### Get details of all files in list
### and the perl modules they are using!

## no critic (ExcessComplexity)
sub get_details {
  my ( $lib_flag, @files ) = @_;

  foreach my $fn (@files) {
    next if -d $fn;
    ## no critic (RequireChecked BriefOpen)
    open my $fh,q(<),$fn;
    my $pod = 0;
    my $raw = 0;
    unless( $fn =~ m{[.]pm\Z}mxs ) {
      my $hash_bang = <$fh>;
      warn "NOT PERL [$fn]\n" unless $hash_bang =~ m{[#]!/.*/perl}mxs;
      next unless $hash_bang =~ m{[#]!/.*/perl}mxs;
    }
    my @lines;
    ## Grab the lines of the file 1-by-one skipping "raw" blocks in codewriter core
    ## and bits cut out with POD!
    while (<$fh>) {
      ## no critic (CascadingIfElse)
      if(m{\A[#][@]raw}mxs) {
        $raw = 1;
      } elsif(m{\A[#][@]endraw}mxs) {
        $raw = 0;
      } elsif(m{\A=cut}mxs) {
        $pod = 0;
        next;
      } elsif( m{\A=\w}mxs) {
        $pod = 1;
      }
      ## use critic
      next if $pod || $raw;
      last if m{\A__END__}mxs;
      last if m{\A__DATA__}mxs;
      push @lines, $_;
    }
    close $fh;
    ## use critic
    ## Now filter out the use lines....
    my @use_lines = map { m{\A\s*use\s+(.*)}mxs ? $1 : () } @lines;

    ## This block is getting "source" and "path" of the current file
    my ($source,$mod_name) = get_source_and_module_name( $lib_flag, $fn );
    $mod_list->{$mod_name}{'in'} ||= $source if $lib_flag eq 'lib';
    my %modules;
    foreach my $line (@use_lines) {
      next if $line =~ m{::%}mxs;
      next if $line =~ m{\A%}mxs;
      next if $line =~ m{\s\d}mxs;
      if( $line =~ m{base\s+(.*)}mxs || $line=~ m{base([(].*)}mxs ) {
        my $list = $1;
        if( $list =~ m{qw\s*[(](.*?)[)]}mxs ||
            $list =~ m{qw\s*[{](.*?)[}]}mxs ||
            $list =~ m{qw\s*\[(.*?)\]}mxs
          ) {
          my $x = $1;
          $x =~s{\A\s+}{}mxs;
          $x =~s{\s+\Z}{}mxs;
          $modules{$_}++ foreach split m{\s+}mxs, $x;
        } else {
          $list =~ s{[^\w:]}{}mxsg;
          $modules{$list}++;
        }
      } elsif( $line =~ m{([\w:]+)}mxs ) {
        $modules{$1}++;
      }
    }
    push @{$mod_list->{$_}{'used'}{ $source }}, $mod_name foreach keys %modules;
  }
  return $mod_list;
}

sub get_source_and_module_name {
  my ($lib_flag,$fn ) = @_;
  my $lr  = 1 + length $ROOT_PATH;
  my $lur = 1 + length $UTILS_PATH;
  my $path = $fn;
     $path =          substr $fn, $lr  if "$ROOT_PATH/"  eq substr $fn,0,$lr;
     $path = 'UTILS/'.substr $fn, $lur if "$UTILS_PATH/" eq substr $fn,0,$lur;

  my $source;
  my $mpath = q();
  if( $path =~ m{\A(.*/)?ext-lib/(.*)}mxs ) {
    $source = $1;
    $mpath  = $2;
    if( $mpath =~ m{\A((?:Bio/)?[^/]+)}mxs ) {
      (my $extra = $1)=~s{[.]pm\Z}{}mxs;
      $source.= "/$extra";
    }
  } elsif( $path =~ m{\A(?:.*/)?lib/(.*)}mxs ) {
    $source = 'svn';
    $mpath  = $1;
  } else {
    $source = 'svn-utils';
    $mpath  = $path;
  }
  $source =~ s{\Asites/([^/]+)[.]sanger[.]ac[.]uk/}{$1}mxs;
  $source =~ s{\Asites/([^/]+)/}{$1}mxs;

  ( my $mod_name = $mpath ) =~ s{[.]pm\Z}{}mxs;
  if( $lib_flag eq 'lib' ) {
    $mod_name = join q(::), split m{/}mxs, $mod_name;
  }
  return ($source,$mod_name);
}

sub search_distro {
  my ($file_name, @files ) = @_;
  my @package;
  if( $PACKMAN_TYPE eq 'debian' ) {
    my @details = $ignore_whats_installed ? () : grep_out( [qw(dpkg -S), @files] );
    if( @details ) {
      foreach (@details) {
        if( m{^(\S+?):}mxs ) {
          push @package, $1;
        }
      }
    } else {
      @details = grep_out( [qw(apt-file search), $file_name] );
      my %mp = map { ($_,1) } @files;
      foreach (@details) {
        chomp;
        s{\s+\Z}{}mxs;
        my($pk, $file) = split m{:\s+}mxs;
        push @package, $pk if $mp{$file};
      }
    }
  } elsif( $PACKMAN_TYPE eq 'redhat' ) {
    my @details = $ignore_whats_installed ? () : grep_out( [qw(rpm -qf), @files]);
    my %s;
    if( @details ) {
      foreach (@details) {
        chomp;
        next if m{\Afile[ ]}mxs;
        s{-\d+(?:[.]\d+)*-\d+(?:[.]\w+){1,3}\Z}{}mxs;
        next if exists $s{$_};
        $s{$_}++;
        push @package, $_;
      }
    } else {
      @details = grep_out( [qw(yum whatprovides), @files] );
      while( my $line = shift @details ) {
        next unless $line =~ m{\S}mxs;
        next if $line =~ m{\A\s}mxs;
        next if $line =~ m{\ARepo\s+:\s}mxs;
        next if $line =~ m{\AMatched\s+from:}mxs;
        next if $line =~ m{\AFilename\s+:\s}mxs;
        if( $line =~ m{\A(\S+?)\s+:\s*}mxs ) {
          my $pck = $1;
          $pck =~ s{\A\d+:}{}mxs;
          $pck =~ s{-\d+(?:[.]\d+)*-\d+(?:[.]\w+){1,3}\Z}{}mxs;
          next if exists $s{$pck};
          $s{$pck}++;
          push @package, $pck;
        }
      }
    }
  }
  return @package;
}

sub get_apache_sources {
  my $mod_dir = "$ROOT_PATH/apache2/mods-enabled";
  my @mods;
  if( opendir my $dh, $mod_dir ) {
    @mods    = grep { !m{^[.]}mxs && -l "$mod_dir/$_" }
               readdir $dh;
  }
  foreach my $mod ( @mods ) {
    my $mod_path = readlink "$mod_dir/$mod";
    $bin_info->{"apache2:$mod"} ={
      'packages'  => [],
      'installed' => [ -e $mod_path ? $mod_path : () ],
    };
    my @package = search_distro( $mod_path, $mod_path );
    next unless @package;
    push @{$bin_info->{"apache2:$mod"}{'packages'}}, @package;
  }
  return;
}

sub get_binary_sources {
  my @commands = @_;

  my $command_dupes = {};
  my $command_info  = {};
  foreach my $command ( @commands ) {
    $command_info->{$command} ={
      'packages'  => [],
      'installed' => [ map { m{(\S+)}mxs ? $1 : () } grep_out( [qw(which), $command] ) ],
    };
    my @package = search_distro( $command,
                map { $_->[0] eq $_->[1] ? $_->[0] : @{$_} }
                map { [$_,abs_path($_)] }
                map { "$_/$command" }
                @MUNGED_PATH,
    );
    next unless @package;
    if(@package > 1) {
      warn qq(Command $command is provided by more than 1 package "@package"\n);
      $command_dupes->{$_}++ foreach @package;
    }
    push @{$command_info->{$command}{'packages'}}, @package;
  }
  return ($command_info, $command_dupes);
}

sub get_module_source {
## Dump the output...
## for summary we want core {stuff in pagesmith}
## and stuff not-in pagesmith separated
  my $core;
  my $non_core    = {};
  my $cpan        = get_cpan();
  my $sources     = {};
  my $inst_flag   = {};
  my %package_dupes;
  foreach my $module ( sort keys %{$mod_list} ) {
    next if exists $mod_list->{$module}{'in'};
    next if exists $PRAGMAS->{$module};

## Is it installed
    my $fn = join q(/), split m{::}mxs, "$module.pm";

    my $flag = eval "require $module"; ## no critic (StringyEval)
    my $eval_error = $EVAL_ERROR || q();
    $flag ||= 0;
    my $installed = q(..);
    unless($flag) {
      if($eval_error =~m {\ACan't[ ]locate[ ](\S+)[ ]in[ ][@]INC}mxs ) {
        $installed = $1 eq $fn ? q(==) : q(??);
      } else {
        $installed = q(??);
      }
    }
    $mod_list->{$module}{'installed'} = $installed;

    my $install_type = q(source);
    my @package = search_distro( $fn, map { "$_/$fn" } @MUNGED_INC );
## This is a package manager installation!
    if( @package ) {
      $install_type = $PACKMAN_TYPE;
      if(@package > 1) {
        warn qq(MODULE $module is provided by more than 1 package "@package"\n);
        $package_dupes{$_}++ foreach @package;
      }
      if( exists $mod_list->{$module}{'used'}{'svn'} ) { ## Only report core modules once!
        $sources->{$PACKMAN_TYPE}{'svn'}{$_}{$module}=1 foreach @package;
      } else {
        foreach my $s ( keys %{$mod_list->{$module}{'used'}} ) { ## But report non-core modules for each group included in!
          $sources->{$PACKMAN_TYPE}{$s}{$_}{$module}=1 foreach @package;
        }
      }
    } else { ## Look to see if we have a CPAN package!
      push @package, $cpan->{$module} if exists $cpan->{$module};
      if( @package ) {
## This is a cpan package!
        $install_type = 'cpan';
        if(@package > 1) {
          warn qq(MODULE $module is provided by more than 1 package "@package"\n);
          $package_dupes{$_}++ foreach @package;
        }
        if( exists $mod_list->{$module}{'used'}{'svn'} ) {
          $sources->{'cpan'}{'svn'}{$_}{$module}=1 foreach @package;
        } else {
          foreach my $s ( keys %{$mod_list->{$module}{'used'}} ) {
            $sources->{'cpan'}{$s}{$_}{$module}=1 foreach @package;
          }
        }
      }
    }
## These are "custom packages!"
    if( @package ) {
      $mod_list->{$module}{'packages'} = \@package;
    } else {
      if( exists $mod_list->{$module}{'used'}{'svn'} ) {
        $sources->{'source'}{'svn'}{$module}{$module}=1;
      } else {
        foreach my $s ( keys %{$mod_list->{$module}{'used'}} ) {
          $sources->{'source'}{$s}{$module}{$module}=1;
        }
      }
    }
    ## Push output for placing in package-summary.txt file...
    @package = ($module) unless @package;
    my $package = join q(; ), @package;
    my $line = sprintf "%2s %-6s %-40s %-40s\t%s\n",
      $mod_list->{$module}{'installed'}||q(XX),
      $install_type, $package, $module, join q(, ), grep { $_ ne 'svn' } sort keys %{$mod_list->{$module}{'used'}};
    if( exists $mod_list->{$module}{'used'}{'svn'} ) {
      $core .= $line;
    } else {
      $non_core->{$_} .= $line foreach keys %{$mod_list->{$module}{'used'}};
    }
    if( $mod_list->{$module}{'installed'} eq q(==) ) {
      $inst_flag->{ $install_type }{$_}=1 foreach @package; ## Set true if package needs installing!
    }
  }
## Now provide data for the packages-by-source & package-install.bash files!
  return ($sources,$core,$non_core,\%package_dupes,$inst_flag);
}

## File 1: package-summary.txt
## Split into sections for core and one each sub area of externals...
## Columns are
##  * state:
##     * ".." installed
##     * "??" installed but gives error
##     * "==" missing
##  * install type:
##     * debian/redhat
##     * cpan
##     * source
##  * source package - either:
##     * debian/redhat package name
##     * cpan install module name
##     * module name if source
##  * module name
##  * list of non-core directories the is used in


## File 2: package-by-source.txt
sub dump_output {
  my ($sources,$core,$non_core,$package_dupes) = @_;

  my @output;
  push @output, "CORE\n==========================\n";
  foreach my $type ( $PACKMAN_TYPE, qw(cpan source) ) {
    next unless exists $sources->{$type}{'svn'};
    my @all_packages = sort keys %{$sources->{$type}{'svn'}};
    next unless @all_packages;
    my @packages = grep { !exists $package_dupes->{$_} } @all_packages;
    push @packages, '*** dupes ***', grep { exists $package_dupes->{$_} } @all_packages;
    push @output, join "\n\t", $type, @packages;
  }
  foreach my $ext ( sort keys %{$non_core} ) {
    my @t_out;
    foreach my $type ( $PACKMAN_TYPE, qw(cpan source) ) {
      next unless exists $sources->{$type}{$ext};
      my @all_packages = sort
                     grep { !exists $sources->{$type}{'svn'}{$_} }
                     keys %{$sources->{$type}{$ext}||{}};
      next unless @all_packages;
      my @packages = grep { !exists $package_dupes->{$_} } @all_packages;
      push @packages, '*** dupes ***', grep { exists $package_dupes->{$_} } @all_packages;
      push @t_out,  join "\n\t", $type, @packages;
    }
    if( @t_out ) {
      push @output, "\n\nNON-CORE: $ext\n==========================\n", @t_out;
    }
  }
## no critic (RequireChecked)
  if( open my $fh, q(>), "$ROOT_PATH/tmp/package-summary.txt" ) {
    print {$fh} "CORE\n==========================\n\n$core\n\n",
      map { "NON-CORE: $_\n==========================\n\n$non_core->{$_}\n\n" } sort keys %{$non_core};
    close $fh;
  }
  if( open my $fh, q(>), "$ROOT_PATH/tmp/package-by-source.txt" ) {
    print {$fh} join "\n", @output, q();
    close $fh;
  }
## use critic
  return;
}

sub dump_bin_structures {
  my( $command_info, $command_dupes ) = @_;
## no critic (RequireChecked LongChainsOfMethodCalls)
  if( open my $fh, q(>), "$ROOT_PATH/tmp/package-dump-bin.txt" ) {
    print {$fh} Data::Dumper->new( [ {'info'=>$command_info,'dupes'=>$command_dupes} ], [ 'bin_info' ] )
      ->Sortkeys(1)->Indent(1)->Terse(1)->Dump;
    close $fh;
  }
## use critic
  return;
}
sub dump_structures {
  my $sources = shift;
## File 3/4: Dumprs of mod_list & sources structures...
## This is a Data dumper structure which can be loaded
## no critic (RequireChecked LongChainsOfMethodCalls)
  if( open my $fh, q(>), "$ROOT_PATH/tmp/package-dump-mod_list.txt" ) {
    print {$fh} Data::Dumper->new( [ $mod_list ], [ 'mod_list' ] )
      ->Sortkeys(1)->Indent(1)->Terse(1)->Dump;
    close $fh;
  }
  if( open my $fh,    q(>), "$ROOT_PATH/tmp/package-dump-sources.txt" ) {
    print {$fh} Data::Dumper->new( [ $sources  ], [ 'sources'  ] )
      ->Sortkeys(1)->Indent(1)->Terse(1)->Dump;
    close $fh;
  }
## use critic
  return;
}

sub dump_bin_install_scripts {
  my( $command_info, $command_dupes ) = @_;
  my @out  = "## bin/lib\n##----------------------------------------\n\n";
  my @pout = "## bin/lib\n##----------------------------------------\n\n";
  my @packages            = map { @{$_->{'packages'}||[]} } values %{$command_info};

  push @packages, @{$OTHER_PACKAGES{$PACKMAN_TYPE}} if exists $OTHER_PACKAGES{$PACKMAN_TYPE};
  my @manual_installed  = grep { !@{$command_info->{$_}{'packages'}}  } keys %{$command_info};
  my @manual_to_install = grep { !@{$command_info->{$_}{'installed'}} } @manual_installed;
  my %packages = map { ($_,1) } @packages;
  @packages = sort keys %packages;
  my @uninstalled_packages;
  foreach (@packages) {
    if( $PACKMAN_TYPE eq 'debian' ) {
      my @cache_res = grep_out( [qw(dpkg -s), $_], '^Status' );
      next if @cache_res;
    } elsif( $PACKMAN_TYPE eq 'redhat' ) {
      my @cache_res = grep_out( [qw(rpm -q), $_]);
      next if @cache_res && $cache_res[0]!~m{[ ]is[ ]not[ ]installed}mxs;
    }
    push @uninstalled_packages, $_;
  }
  push @out,    bash_line( $PACKMAN_TYPE, $command_dupes, @packages             );
  push @pout,   bash_line( $PACKMAN_TYPE, $command_dupes, @uninstalled_packages );
  push @out,    bash_line( 'source', $command_dupes, @manual_installed          );
  push @pout,   bash_line( 'source', $command_dupes, @manual_to_install         );
  ## no critic (RequireChecked)
  if( open my $fh, q(>), "$ROOT_PATH/tmp/package-install.bash" ) {
    print {$fh}  @out;
    close $fh;
  }
  if( open my $fh, q(>), "$ROOT_PATH/tmp/package-patch.bash" ) {
    print {$fh} @pout;
    close $fh;
  }
  ## use critic
  return;
}

sub dump_install_scripts {
  my ($sources,$extra_paths,$package_dupes, $inst_flag) = @_;

## File 5/6: package-install.bash && package-patch.bash
## A bash script which can be run to indicate which modules need to be installed!
  ## Now write the bash script...
## NEED TO CHECK FOR DUPLICATES HERE TO SEE IF WE HAVE PACKAGES WHICH
## PUSH SAME MODULE!!!!
  my @out  = "## core\n##----------------------------------------\n\n";
  my @pout = "## core\n##----------------------------------------\n\n";
  foreach my $type ( $PACKMAN_TYPE, qw(cpan source) ) {
    my @packages = sort keys %{$sources->{$type}{'svn'}};
    push @out,  bash_line( $type, $package_dupes, @packages );
    ## Just get all those that need installing!
    push @pout, bash_line( $type, $package_dupes, grep { exists $inst_flag->{$type}{$_} && $inst_flag->{$type}{$_} } @packages );
  }
  foreach my $ext ( @{$extra_paths} ) {
    push @out,  "## $ext\n##----------------------------------------\n\n";
    push @pout, "## $ext\n##----------------------------------------\n\n";
    foreach my $type ( $PACKMAN_TYPE, qw(cpan source) ) {
      my @packages = sort grep { !exists $sources->{$type}{'svn'}{$_} }
                     keys %{$sources->{$type}{$ext}||{}};
      push @out,  bash_line( $type, $package_dupes, @packages );
      ## Just get all those that need installing!
      push @pout, bash_line( $type, $package_dupes, grep { exists $inst_flag->{$type}{$_} && $inst_flag->{$type}{$_} } @packages );
    }
  }

  ## no critic (RequireChecked)
  if( open my $fh, q(>>), "$ROOT_PATH/tmp/package-install.bash" ) {
    print {$fh}  @out;
    close $fh;
  }
  if( open my $fh, q(>>), "$ROOT_PATH/tmp/package-patch.bash" ) {
    print {$fh} @pout;
    close $fh;
  }
  ## use critic
  return;
}

sub bash_line {
  my ($type, $package_dupes, @all_packages ) = @_;
  return unless @all_packages;
  my @out;
  my @packages = grep { !exists $package_dupes->{$_} } @all_packages;
  push @out, sprintf "%s %s\n\n", $PACKAGE_PATH->{$type}, "@packages" if @packages;
  my @dupes    = grep { exists $package_dupes->{$_} } @all_packages;
  if( @dupes ) {
    push @out, sprintf "# The following packages include the same module\n# %s %s\n\n", $PACKAGE_PATH->{$type}, "@dupes";
  }
  return join q(), @out;
}

## These four function get information
sub get_munged_inc {
  my %seen;
  my @paths;
  foreach ( map { ($_,abs_path($_)) } @INC ) {
    next unless defined $_;
    next if $seen{$_};
    $seen{$_}++;
    push @paths, $_;
  }
  return grep { -d $_ } @paths;
}

sub get_munged_path {
  my %seen;
  my @paths;
  foreach ( map { ($_,abs_path($_)) } split m{:}mxs, $ENV{'PATH'} ) {
    next unless defined $_;
    next if $seen{$_};
    $seen{$_}++;
    push @paths, $_;
  }
  return grep { -d $_ } @paths;
}

sub get_dirs {
  ## Returns array of paths....
  my @ldirs   = ($ROOT_PATH);
  my $dh;
  if( opendir $dh, "$ROOT_PATH" ) {
    push @ldirs, map { "$ROOT_PATH/$_" } grep { !m{^[.]}mxs && -d "$ROOT_PATH/$_" } readdir $dh;
  }
  if( opendir $dh, "$ROOT_PATH/sites" ) {
    push @ldirs, map { "$ROOT_PATH/sites/$_" } grep { !m{^[.]}mxs && -d "$ROOT_PATH/sites/$_" } readdir $dh;
  }
  return @ldirs;
}

sub get_libs {
  my $libs = shift;
  find( sub {
    return if exc($File::Find::name);
    return unless $File::Find::name =~ m{[.]pm\Z}mxs;
    push @libs, $File::Find::name;
  }, $_ ) foreach @{$libs};
  return;
}

sub get_scripts {
  my $scrs = shift;
  find( sub {
    return if exc($File::Find::name);
    warn 'LIB IN SCRIPTS ',$File::Find::name,"\n" if $File::Find::name =~ m{[.]pm\Z}mxs;
    return if $File::Find::name =~ m{[.]pm\Z}mxs;
    push @scrs, $File::Find::name;
  }, $_ ) foreach @{$scrs};
  return;
}

## Function return true if skipping directory or file!
sub exc {
  my $fn = shift;
  return 1 if -d $fn;
  return 1 if $fn =~ m{/.svn/}mxs || $fn =~ m{/CVS/}mxs;
  return 1 if $fn =~ m{/[.]}mxs;
  return 1 if $fn =~ m{~\Z}mxs;
  return 0;
}

sub get_cpan {
  my $cpan      = {};
  my $cpan_file = {};
  my $ua = LWP::UserAgent->new;
     $ua->env_proxy;
  my $contents = $ua->get( $CPAN_PACKAGES )->content;
  my @lines = split m{[\r\n]}mxs, $contents;
  while( $_ = shift @lines ) {
    last if m{\A\s*\Z}mxs;
  }
  while( $_ = shift @lines ) {
    chomp;
    my( $pkg, $version, $file ) = split m{\s+}mxs;
    $cpan->{$pkg} = $cpan_file->{$file}||=$pkg;
  }
  return $cpan;
}

sub grep_out {
  my ( $command_ref, $match, $input ) = @_;
  my $res = run_cmd( $command_ref, $input );
  return unless $res->{'success'};
  return @{$res->{'stdout'}||[]} unless defined $match;
  return map { $_ =~ m{$match}mxs ? (defined $1?$1:$_) : () } @{$res->{'stdout'}||[]};
}

sub run_cmd {
  my ( $command_ref, $input_ref ) = @_;

  $input_ref ||= [];
  my $out_ref  = [];
  my $err_ref  = [];
  my $ret = eval { run3 $command_ref, $input_ref, $out_ref, $err_ref; };
  ## no critic (PunctuationVars)
  my $res = {(
    'command' => $command_ref,
    'success' => $ret && !$?,
    'error'   => $@ || $?,
    'stdout'  => resplit( $out_ref ),
    'stderr'  => resplit( $err_ref ),
  )};
  if( $verbose ) {
    my $msg = sprintf '
  - Command ------------------------------------------------------------
  %s
  - FLAGS --------------------------------------------------------------
   [%s] %s
  - STDOUT -------------------------------------------------------------
  %s
  - STDERR -------------------------------------------------------------
  %s
', "@{$command_ref}",
     $res->{'success'}, $res->{'error'},
     map { join qq(\n  ), @{$res->{$_}||[]} } qw(stdout stderr);
    warn "$msg\n";
  }
  return $res;
  ## use critic
}

sub resplit {
  my $a_ref = shift;
  my @ret = map { split m{\r?\n}mxs, $_ } @{$a_ref};
  return \@ret;
}
