#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use English qw(-no_match_vars $PROGRAM_NAME);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Getopt::Long qw(GetOptions);
use Const::Fast qw(const);
use English qw(-no_match_vars $UID);

const my $DIR_PERM => 0755; ## no critic (LeadingZeros)

my $ROOT_PATH;
BEGIN { $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME))); }
use lib "$ROOT_PATH/lib";

my $from_svn;
my $name_space;
my $commit_svn;
my $htdocs_sub_dir;
my $apache_dir;
my $template_name = 'nav';

GetOptions(
  'svn:s'       => \$from_svn,
  'htdocs:s'    => \$htdocs_sub_dir,
  'namespace:s' => \$name_space,
  'commit'      => \$commit_svn,
  'apache:s'    => \$apache_dir,
  'template:s'  => \$template_name,
);

my $domain_name = shift @ARGV;

die "MUST GIVE DOMAIN NAME\n" unless $domain_name;

## Read files from __DATA__ section of file...
my $file_contents = {};
get_templates();

## Create directories
create_directories();

## and files within them
my $conf_file     = $apache_dir ? "$ROOT_PATH/apache2/$apache_dir/sites-available/$domain_name" : "$ROOT_PATH/apache2/sites-enabled/$domain_name";
my $rel_conf_file = $apache_dir ? "../$apache_dir/sites-available/$domain_name" : q();
my @date = gmtime;
my $date = sprintf '%04d-%02d-%02d', $date[5]+1900,$date[4]+1,$date[3]; ## no critic (MagicNumbers)
my $user = sprintf '%s (%s)',        @{[getpwuid $UID]}[qw(0 6)];
create_files();

## And if required write back to the SVN repository with pass 1!
if( $from_svn ) {
  write_svn();
} else {
  checkout_core();
}

sub get_templates {
  ## no critic (RequireChecked)
  my $key;
  open my $t_fh, q(<), "$ROOT_PATH/config/data/site-templates.txt";
  while(my $line =<$t_fh>) {
    if( $line =~ m{\A!!\s+(\S+)}mxs ) {
      $key = $1;
      $file_contents->{$key} = q();
      next;
    }
    $file_contents->{$key} .= $line;
  }
  close $t_fh;
  return;
  ## use critic
}
sub create_directories {
  my @paths = qw(htdocs data data/templates data/templates/normal data/config source utilities lib ext-lib lib/Pagesmith);
  push @paths, "htdocs/$htdocs_sub_dir", map { "htdocs/$htdocs_sub_dir/$_" } qw(css gfx inc js assets);
  (my $repos_name = $domain_name) =~ s{[.]}{-}mxsg;

  ### Create root directory of site either from SVN or just with mkdir.!
  if( -d "$ROOT_PATH/sites/$domain_name" ) {
    if( $options{ 's' } ) {
      `svn up $ROOT_PATH/sites/$domain_name`; ## no critic (BacktickOperators)
    }
  } else {
    if( $from_svn ) {
      `svn co $from_svn/sites/$repos_name/trunk $ROOT_PATH/sites/$domain_name`; ## no critic (BacktickOperators)
    } else {
      mkdir "$ROOT_PATH/sites/$domain_name", $DIR_PERM;
    }
  }

  ## Make site directories....
  foreach( @paths ) {
    mkdir "$ROOT_PATH/sites/$domain_name/$_", $DIR_PERM unless -e "$ROOT_PATH/sites/$domain_name/$_";
  }
  return;
}

sub checkout_core {
  ## no critic (BacktickOperators)
  if( -e "$ROOT_PATH/sites/$domain_name/htdocs" ) {
    `svn up $ROOT_PATH/sites/$domain_name/htdocs`;
  } else {
    `svn co http://websvn.europe.sanger.ac.uk/svn/pagesmith-core/trunk/htdocs/core $ROOT_PATH/sites/$domain_name/htdocs`;
  }
  ## use critic
  return;
}

sub write_svn {
  ## no critic (BacktickOperators)
  `svn add -q $ROOT_PATH/sites/$domain_name/*`;
  my @Q = `svn pg svn:externals $ROOT_PATH/sites/$domain_name/htdocs`;
  `svn ps svn:externals 'core http://websvn.europe.sanger.ac.uk/svn/pagesmith-core/trunk/htdocs/core' $ROOT_PATH/sites/$domain_name/htdocs` unless @Q;
     @Q = `svn pg svn:ignore $ROOT_PATH/sites/$domain_name/ext-lib`;
  `svn ps svn:ignore '*' $ROOT_PATH/sites/$domain_name/ext-lib` unless @Q;
     @Q = `svn info $ROOT_PATH/sites/$domain_name | grep Revision`;
  if( $Q[0] =~ m{\ARevision:[ ]1}mxs ) {
    `svn ci -m 'creating initial site structure' $ROOT_PATH/sites/$domain_name` if $commit_svn;
  } else {
    `svn ci -m 'patching site  structure' $ROOT_PATH/sites/$domain_name` if $commit_svn;
  }
  if( $apache_dir && $commit_svn ) {
    `svn add -q $conf_file`;
    `svn ci -m 'adding site config' $conf_file`;
  }
  `svn up $ROOT_PATH/sites/$domain_name`;
  ## use critic
  return;
}

my $directories_to_skip = map {($_,1)} qw(Startup Support Apache Apache/Action);

sub create_files {
  ## Create standard html pages, index, legal, cookiespolicy, contact
  ## no critic (RequireChecked)
  foreach (qw(index contact cookiespolicy legal)) {
    next unless exists $file_contents->{"$_.html"};
    next if -e "$ROOT_PATH/sites/$domain_name/htdocs/$_.html";
    open my $fh, q(>), "$ROOT_PATH/sites/$domain_name/htdocs/$_.html";
    print {$fh} expand_parts( $file_contents->{"$_.html"} );
    close $fh;
  }
  foreach (qw(css js)) {
    next unless exists $file_contents->{$_};
    next if -e "$ROOT_PATH/sites/$domain_name/htdocs/$htdocs_sub_dir/$_/$htdocs_sub_dir.$_";
    open my $fh, q(>), "$ROOT_PATH/sites/$domain_name/htdocs/$htdocs_sub_dir/$_/$htdocs_sub_dir.$_";
    print {$fh} expand_parts( $file_contents->{$_} );
    close $fh;
  }

  ## Create template page...
  unless( -e "$ROOT_PATH/sites/$domain_name/data/templates/normal/$domain_name.tmpl" ) {
    open my $ti_fh, q(>), "$ROOT_PATH/sites/$domain_name/data/templates/normal/$domain_name.tmpl";
    print {$ti_fh} expand_parts( $file_contents->{ $template_name.'-template' } );
    close $ti_fh;
  }
  unless( -e "$ROOT_PATH/sites/$domain_name/data/config/databases.yaml" ) {
    open my $d_fh, q(>), "$ROOT_PATH/sites/$domain_name/data/config/databases.yaml";
    print {$d_fh} $file_contents->{'databases.yaml'};
    close $d_fh;
  }
  ## Write the apache configuration file....
  unless( -e "$ROOT_PATH/sites/$domain_name/data/config/databases.yaml" ) {
    open my $conf_fh, q(>), $conf_file;
    print {$conf_fh} expand_parts($file_contents->{'apache.conf'});
    close $conf_fh;
  }
  unless( -e "$ROOT_PATH/apache2/sites-enabled" ) {
    `ln -s $rel_conf_file $ROOT_PATH/apache2/sites-enabled`; ## no critic (BacktickOperators)
  }
  ## Create lib directories, and insert boiler plate modules!
  if( $name_space ) {
    foreach (qw(Apache Apache/Action Adaptor Object Component Action Startup Support)) {
      mkdir "$ROOT_PATH/sites/$domain_name/lib/Pagesmith/$_", $DIR_PERM unless -e "$ROOT_PATH/sites/$domain_name/lib/Pagesmith/$_";
      if( exists $file_contents->{$_} ) {
        unless( -e "$ROOT_PATH/sites/$domain_name/lib/Pagesmith/$_/$name_space.pm" ) {
          open my $fh, q(>), "$ROOT_PATH/sites/$domain_name/lib/Pagesmith/$_/$name_space.pm";
          print {$fh} expand_parts( $file_contents->{$_} );
          close $fh;
        }
      }
      next if exists $directories_to_skip{$_};
      next if -e "sites/$domain_name/lib/Pagesmith/$_/$name_space";
      mkdir "sites/$domain_name/lib/Pagesmith/$_/$name_space", $DIR_PERM;
    }
  }
  ## use critic
  return;
}

sub expand_parts {
  my $string = shift;
  (my $shortened_domain_name = $domain_name ) =~ s{\Awww[.]}{}mxs;
  ## no critic (InterpolationOfMetachars)
  my $map = { 'DomainName'     => $domain_name,
              'NameSpace'      => $name_space,
              'LowerNameSpace' => lc $name_space,
              'HtdocsSubDir'   => $htdocs_sub_dir,
              'Author'         => $user,
              'ApacheDir'      => $apache_dir || 'core.d',
              'ShortDomainName'  => $shortened_domain_name,
              'BoilerPlate'    => sprintf '## Author         : %s
## Maintainer     : %s
## Created        : %s
## Last commit by : $Author $
## Last modified  : $Date $
## Revision       : $Revision $
## Repository URL : $HeadURL $', $user, $user, $date,
            };
  ## use critic
  $string =~ s{\[\[(\w+)\]\]}{$map->{$1}||"YARG{{$1}}"}mxseg;
  return $string;
}

