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

use HTML::Entities qw(encode_entities);

use Time::HiRes    qw(time);
use English        qw(-no_match_vars $PROGRAM_NAME $EVAL_ERROR $OUTPUT_AUTOFLUSH);
use File::Basename qw(dirname);
use Cwd            qw(abs_path);
use Data::Dumper; ## no xcritic (DebuggingModules)
use File::Find     qw(find);
use Compress::Zlib qw(gzopen);

my $pragmas = { map { $_ => 1 } qw(strict warnings utf8 version feature integer lib vars) };
my $ROOT_PATH;
BEGIN {
  $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME)));
}
use lib "$ROOT_PATH/lib";

my( $lib_paths, $scr_paths ) = get_dirs();
my $UTILS_PATH = dirname($ROOT_PATH);
push @{$lib_paths}, "$UTILS_PATH/utilities/lib";
push @{$scr_paths}, "$UTILS_PATH/utilities";
## make this global
my @libs;
my @scrs;
my $mod_list = {};
get_libs( $lib_paths );
#warn "@libs\n\n";
get_details( 'lib', @libs );
get_scripts( $scr_paths );
#warn "@scrs\n\n";
get_details( 'scr', @scrs );
dump_output();
## end of main!

sub get_dirs {
  my( @lib_paths, @scr_paths );
  push @lib_paths, "$ROOT_PATH/lib";
  push @scr_paths, "$ROOT_PATH/utilities";
  push @lib_paths, "$ROOT_PATH/ext-lib" if -d "$ROOT_PATH/ext-lib";

## First loop through all site-level modules;
  my $dh;
  if( opendir $dh, "$ROOT_PATH" ) {
    while ( defined (my $file = readdir $dh) ) {
      next if $file =~ m{\A[.]}mxs;
      push @lib_paths, "$ROOT_PATH/$file/lib"       if -d "$ROOT_PATH/$file/lib";
      push @lib_paths, "$ROOT_PATH/$file/ext-lib"   if -d "$ROOT_PATH/$file/ext-lib";
      push @scr_paths, "$ROOT_PATH/$file/utilities" if -d "$ROOT_PATH/$file/utilities";
    }
    closedir $dh;
  }

  if( opendir $dh, "$ROOT_PATH/sites" ) {
    while ( defined (my $file = readdir $dh) ) {
      next if $file =~ m{\A[.]}mxs;
      push @lib_paths, "$ROOT_PATH/sites/$file/lib"       if -d "$ROOT_PATH/sites/$file/lib";
      push @lib_paths, "$ROOT_PATH/sites/$file/ext-lib"   if -d "$ROOT_PATH/sites/$file/ext-lib";
      push @scr_paths, "$ROOT_PATH/sites/$file/utilities" if -d "$ROOT_PATH/sites/$file/utilities";
  }
    closedir $dh;
  }
  return \@lib_paths, \@scr_paths;
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


sub exc {
  my $fn = shift;
  return 1 if -d $fn;
  return 1 if $fn =~ m{/.svn/}mxs || $fn =~ m{/CVS/}mxs;
  return 1 if $fn =~ m{/[.]}mxs;
  return 1 if $fn =~ m{~\Z}mxs;
  return 0;
}

## no critic (ExcessComplexity)
sub get_details {
  my ( $lib_flag, @files ) = @_;
  my $lr  = 1 + length $ROOT_PATH;
  my $lur = 1 + length $UTILS_PATH;
  foreach my $fn (@files) {
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
    my @use_lines = map { m{\A\s*use\s+(.*)}mxs ? $1 : () } @lines;
    my $path = $fn;
       $path =          substr $fn, $lr  if "$ROOT_PATH/"  eq substr $fn,0,$lr;
       $path = 'UTILS/'.substr $fn, $lur if "$UTILS_PATH/" eq substr $fn,0,$lur;
    my $source;
    my $mpath = q();
    if( $path =~ m{\A(?:.*/)?lib/(.*)}mxs ||
        $path =~ m{\A(?:.*/)?utilities/(.*)}mxs
    ) {
      $source = 'svn';
      $mpath  = $1;
    } elsif( $path =~ m{\A(.*/)?ext-lib/(.*)}mxs ) {
      $source = $1;
      $mpath  = $2;
      if( $mpath =~ m{\A((?:Bio/)?[^/]+)}mxs ) {
        (my $extra = $1)=~s{[.]pm\Z}{}mxs;
        $source.= "/$extra";
      }
    }
    $source =~ s{\Asites/([^/]+)[.]sanger[.]ac[.]uk/}{$1}mxs;
    $source =~ s{\Asites/([^/]+)/}{$1}mxs;
    ( my $mod_name = $mpath ) =~ s{[.]pm\Z}{}mxs;
    if( $lib_flag eq 'lib' ) {
      $mod_name = join q(::), split m{/}mxs, $mod_name;
    }
    #printf "%3d %s                                       [%s]\n", scalar @use_lines, $mod_name, $source;
    $mod_list->{$mod_name}{'in'} ||= $source if $lib_flag eq 'lib';
    my %modules;
    foreach my $l (@use_lines) {
      next if $l =~ m{::%}mxs;
      next if $l =~ m{\A%}mxs;
      next if $l =~ m{\s\d}mxs;
      if( $l =~ m{base\s+(.*)}mxs || $l=~ m{base([(].*)}mxs ) {
        my $p = $1;
        if( $p =~ m{qw\s*[(](.*?)[)]}mxs ||
            $p =~ m{qw\s*[{](.*?)[}]}mxs ||
            $p =~ m{qw\s*\[(.*?)\]}mxs
          ) {
          my $x = $1;
          $x =~s{\A\s+}{}mxs;
          $x =~s{\s+\Z}{}mxs;
          $modules{$_}++ foreach split m{\s+}mxs, $x;
        } else {
          $p =~ s{[^\w:]}{}mxsg;
          $modules{$p}++;
        }
      } elsif( $l =~ m{([\w:]+)}mxs ) {
        $modules{$1}++;
      }
    }
    push @{$mod_list->{$_}{'used'}{ $source }}, $mod_name foreach keys %modules;
  }
  return $mod_list;
}


sub dump_output {
## Dump the output...
## for summary we want core {stuff in pagesmith}
## and stuff not-in pagesmith separated
  my $core;
  my $non_core = {};
  my $cpan = get_cpan();
  my $sources = {};
  foreach my $module ( sort keys %{$mod_list} ) {
    next if exists $mod_list->{$module}{'in'};
    next if exists $pragmas->{$module};
    my $fn = join q(/), split m{::}mxs, "$module.pm";
    my @details = `dpkg -S $fn 2>/dev/null`; ## no critic (BackTickOperators)
    my @package;
    foreach ( @details ) {
      chomp;
      s{\s+\Z}{}mxs;
      my( $pck, $pth ) = split m{:[ ]}mxs, $_;
      $pth =~ s{\A.*?/perl\d*/}{}mxs;
      $pth =~ s{\A\d+[.]\d+[.]\d+/}{}mxs;
      if( $pth eq $fn ) {
        push @package, $pck;
      }
      if( exists $mod_list->{$module}{'used'}{'svn'} ) {
        $sources->{'ubuntu'}{'svn'}{$_}++ foreach @package;
      } else {
        foreach my $s ( keys %{$mod_list->{$module}{'used'}} ) {
          $sources->{'ubuntu'}{$s}{$_}++ foreach @package;
        }
      }
    }
    unless( @package ) {
      @package = map { cpan_pack( $_ ) } @{$cpan->{$module}||[]};
      if( exists $mod_list->{$module}{'used'}{'svn'} ) {
        $sources->{'cpan'}{'svn'}{$_}++ foreach @package;
      } else {
        foreach my $s ( keys %{$mod_list->{$module}{'used'}} ) {
          $sources->{'cpan'}{$s}{$_}++ foreach @package;
        }
      }
    }
    unless( @package ) {
      if( exists $mod_list->{$module}{'used'}{'svn'} ) {
        $sources->{'other'}{'svn'}{$module}++;
      } else {
        foreach my $s ( keys %{$mod_list->{$module}{'used'}} ) {
          $sources->{'other'}{$s}{$module}++;
        }
      }
    }
    my $package = @package ? join q(; ),@package : '###############';
    my $line = sprintf "%-40s %-40s\t%s\n", $package, $module, join q(, ), grep { $_ ne 'svn' } sort keys %{$mod_list->{$module}{'used'}};
    if( exists $mod_list->{$module}{'used'}{'svn'} ) {
      $core .= $line;
    } else {
      $non_core->{$_} .= $line foreach keys %{$mod_list->{$module}{'used'}};
    }
  }
  ## no critic (BriefOpen RequireChecked)
  open my $fh, q(>), "$ROOT_PATH/tmp/package-summary.txt";
  print {$fh} "CORE\n==========================\n\n$core\n\n";
  foreach (sort keys %{$non_core}) {
    print {$fh} "NON-CORE: $_\n==========================\n\n$non_core->{$_}\n\n";
  }
  close $fh;

  open $fh, '>', "$ROOT_PATH/tmp/package-details-dump.txt";
  print {$fh} Data::Dumper->new( [ $mod_list ], [ 'mod_list' ] )->Sortkeys(1)->Indent(1)->Terse(1)->Dump; ## no critic (LongChainsOfMethodCalls)
  close $fh;

  my @output;
  push @output, "CORE\n==========================\n";
  foreach my $type ( qw(ubuntu cpan other) ) {
    my @packages = sort keys %{$sources->{$type}{'svn'}};
    if( @packages ) {
      push @output, join "\n\t", $type, @packages;
    }
  }
  foreach my $ext ( sort keys %{$non_core} ) {
    my @t_out;
    foreach my $type ( qw(ubuntu cpan other) ) {
      my @packages = sort
                     grep { !exists $sources->{$type}{'svn'}{$_} }
                     keys %{$sources->{$type}{$ext}||{}};
      if( @packages ) {
        push @t_out, join "\n\t", $type, @packages;
      }
    }
    if( @t_out ) {
      push @output, "\n\nNON-CORE: $ext\n==========================\n", @t_out;
    }
  }
  push @output,q();
  open $fh, '>', "$ROOT_PATH/tmp/package-by-source.txt";
  print {$fh} join "\n", @output;
  close $fh;
  ## use critic
  return;
}

sub cpan_pack {
  ( my $x = shift ) =~ s{^.*/}{}mxs;
  $x =~ s{[.].*}{}mxs;
  $x =~ s{-\d+}{}mxs;
  $x =~ s{-}{::}mxsg;
  return $x;
}

sub get_cpan {
  my $gz   = gzopen( '/nfs/users/nfs_j/js5/.cpan/sources/modules/02packages.details.txt.gz', 'r' );
  my $cpan = {};
  my $line;
  while( $gz->gzreadline( $line ) ) {
    last if $line =~m{\A\s*\Z}mxs;
  }
  while( $gz->gzreadline( $line ) ) {
    chomp $line;
    my( $pkg, $version, $file ) = split m{\s+}mxs, $line;
    push @{$cpan->{$pkg}}, $file;
  }
  $gz->gzclose;
  return $cpan;
}

