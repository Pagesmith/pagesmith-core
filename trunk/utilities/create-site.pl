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
use IPC::Run3 qw(run3);

const my $DIR_PERM       => 0755; ## no critic (LeadingZeros)
const my %VALID_BRANCHES => qw(trunk dev staging live live live);
const my $DEF_BRANCH     => 'trunk';
const my $DEF_TEMPLATE   => 'nav';
const my $DEF_SVN        => 'http://websvn.europe.sanger.ac.uk/svn';
my %directories_to_skip = map {($_,1)} qw(Startup Support Apache Apache/Action);

my $ROOT_PATH;
BEGIN { $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME))); }
use lib "$ROOT_PATH/lib";

my $from_svn;
my $name_space;
my $htdocs_sub_dir;
my $setup_key;
my $branch        = $DEF_BRANCH;
my $template_name = $DEF_TEMPLATE;
my $core_svn_path = $DEF_SVN;

## Flags
my $dryrun        = 0;
my $commit_svn    = 0;
my $verbose       = 0;
my $quiet         = 0;

guess_defaults();

GetOptions(
  'branch:s'    => \$branch,            ## guess
  'commit'      => \$commit_svn,
  'dryrun'      => \$dryrun,
  'htdocs:s'    => \$htdocs_sub_dir,
  'key:s'       => \$setup_key,        ## guess
  'namespace:s' => \$name_space,
  'quiet'       => \$quiet,
  'repos:s'     => \$core_svn_path,     ## guess
  'svn:s'       => \$from_svn,          ## guess
  'template:s'  => \$template_name,
  'verbose'     => \$verbose,
);

diedoc( 'MUST GIVE DOMAIN NAME' ) unless @ARGV;

my $domain_name    = shift @ARGV;
(my $repos_name = $domain_name) =~ s{[.]}{-}mxsg;
## Read files from __DATA__ section of file...
my $file_contents = {};

pre_flight_checks();

warn "Setting up with the following options:
  Domain:            $domain_name
  SVN repository:    $from_svn
  Check in SVN:      $commit_svn
  Apache dir:        $setup_key.d
  Branch:            $branch
  Externals from:    $core_svn_path/pagesmith-core/$branch
  Setup key:         $setup_key
  Site details:
    Repository:      $from_svn/sites/$repos_name/$branch
    Directory:       $ROOT_PATH/sites/$domain_name
    Config fiile:    $ROOT_PATH/apache2/$setup_key.d/$domain_name.conf
" unless $quiet;

die "\n###################### DRY RUN ONLY ######################\n\n" if $dryrun;

get_templates();

my $conf_file     = $setup_key ? "$ROOT_PATH/apache2/$setup_key.d/sites-available/$domain_name.conf$domain_name.conf" : "$ROOT_PATH/apache2/sites-enabled/$domain_name.conf";
my $rel_conf_file = $setup_key ? "../$setup_key.d/sites-available/$domain_name.conf" : q();
my @date = gmtime;
my $date = sprintf '%04d-%02d-%02d', $date[5]+1900,$date[4]+1,$date[3]; ## no critic (MagicNumbers)
my $user = sprintf '%s (%s)',        @{[getpwuid $UID]}[qw(0 6)];

## Create directories and files!
create_directories();
create_files();
create_perl_files();

## And if required write back to the SVN repository with pass 1!
if( $from_svn ) {
  write_svn();
} else {
  checkout_core();
}

sub guess_defaults {
  ## setup_key
  ## branch
  ## from_svn
  my ($repos) = grep_out( [qw(svn info), $ROOT_PATH], 'URL:[ ](.*)' );
  if( $repos && $repos =~ m{(.*)/pagesmith/(\w+)-core/(\w+)}mxs ) {
    $from_svn   = $1;
    $setup_key = $2;
    $branch     = $3;
  }
  ## core_svn_path
  my ($core_repos) = grep_out( [qw(svn info), "$ROOT_PATH/htdocs"], 'URL:[ ](.*?)/pagesmith-core/.*/htdocs' );
  $core_svn_path = $core_repos if $core_repos;
  return;
}

sub pre_flight_checks {
  diedoc( 'Cannot find apache dir' ) unless -e "$ROOT_PATH/apache2/$setup_key.d";
  ## Check to see if valid branch name
  diedoc( 'Invalid branch' ) unless exists $VALID_BRANCHES{$branch};
  ## Check to see if externals SVN repository exists
  diedoc( "Invalid SVN protocol/path: $core_svn_path" )
    unless $core_svn_path =~ m{\A(?:(?:svn(?:[+]\w+)?|https?)://[-\w]+|file:///)\w}mxs;
  diedoc( "Repository '$core_svn_path/pagesmith-core' doesn't exists\n" )
    unless grep_out( ['svn', 'info', "$core_svn_path/pagesmith-core"], 'Revision:[ ](\d+)' );
  ## Check to see if local SVN repository exists
  diedoc( "Invalid SVN protocol/path: $from_svn" )
    unless $from_svn =~ m{\A(?:(?:svn(?:[+]\w+)?|https?)://[-\w]+|file://)/\w}mxs;
  diedoc( "Repository '$from_svn/sites/$repos_name' doesn't exists\n" )
    unless grep_out( ['svn', 'info', "$from_svn/sites/$repos_name"], 'Revision:[ ](\d+)' );

  $htdocs_sub_dir = sprintf '%s-core', lc $name_space unless $htdocs_sub_dir;
  $name_space     = ucfirst $name_space;

  warn "#### Preflight checks passed\n" unless $quiet;
  $commit_svn = ! $commit_svn;
  return;
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
  warn "Templates file read\n" unless $quiet;
  return;
  ## use critic
}

sub create_directories {
  my @paths = qw(htdocs data data/templates data/templates/normal data/config source utilities lib ext-lib lib/Pagesmith);
  push @paths, "htdocs/$htdocs_sub_dir", map { "htdocs/$htdocs_sub_dir/$_" } qw(css gfx inc js assets);

  ### Create root directory of site either from SVN or just with mkdir.!
  if( -d "$ROOT_PATH/sites/$domain_name" ) {
    if( $from_svn ) {
      run_cmd( [qw(svn up), "$ROOT_PATH/sites/$domain_name"] );
    }
  } else {
    if( $from_svn ) {
      my $flag = grep_out( ['svn', 'info', "$from_svn/sites/$repos_name/$branch"], 'Revision:[ ](\d+)' );
      run_cmd( ['svn', 'mkdir', '-m', "adding $branch branch",
          "$from_svn/sites/$repos_name/$branch" ] ) unless $flag;
      run_cmd( ['svn', 'co', "$from_svn/sites/$repos_name/$branch",
        "$ROOT_PATH/sites/$domain_name" ] );
    } else {
      mkdir "$ROOT_PATH/sites/$domain_name", $DIR_PERM;
    }
  }

  ## Make site directories....
  foreach( @paths ) {
    mkdir "$ROOT_PATH/sites/$domain_name/$_", $DIR_PERM unless -e "$ROOT_PATH/sites/$domain_name/$_";
  }
  warn "Directories created\n" unless $quiet;
  return;
}

sub checkout_core {
  if( -e "$ROOT_PATH/sites/$domain_name/htdocs" ) {
    run_cmd( ['svn', 'up', "$ROOT_PATH/sites/$domain_name/htdocs"]);
    warn "Core htdocs updated\n" unless $quiet;
  } else {
    run_cmd( ['svn', 'co',
      "$core_svn_path/pagesmith-core/$branch/core",
      "$ROOT_PATH/sites/$domain_name/htdocs"]);
    warn "Core htdocs checkdout\n" unless $quiet;
  }
  return;
}

sub write_svn {
  foreach (qw(htdocs data source utilities lib ext-lib)) {
    run_cmd( [qw(svn add -q), "$ROOT_PATH/sites/$domain_name/$_"] );
  }
  unless( grep_out( [qw(svn pg svn:externals), "$ROOT_PATH/sites/$domain_name/htdocs"] ) ) {
    my $externals  = "core $core_svn_path/pagesmith-core/$branch/htdocs/core";
       $externals .= sprintf "\n %s %s", $setup_key, "$from_svn/pagesmith/$setup_key-core/$branch/htdocs/core-$setup_key";
    run_cmd( [qw(svn ps svn:externals), $externals, "$ROOT_PATH/sites/$domain_name/htdocs" ] );
  }
  unless( grep_out( [qw(svn pg svn:ignore), "$ROOT_PATH/sites/$domain_name/ext-lib"] )) {
    run_cmd( [qw(svn ps svn:ignore), q(*), "$ROOT_PATH/sites/$domain_name/ext-lib"] );
  }
  warn "#### SVN externals etc setup\n" unless $quiet;
  my $commits = grep_out([qw(svn log), "$ROOT_PATH/sites/$domain_name/"], '----------' );
  $commits--;
  run_cmd([qw(svn ci -m),
    $commits == 1 ? 'creating initial site structure'
                  : 'patching site structure',
    "$ROOT_PATH/sites/$domain_name/"]) if $commit_svn;
  warn "#### SVN repository committed\n" if $commit_svn && !$quiet;
  run_cmd([qw(svn up), "$ROOT_PATH/sites/$domain_name/"]);
  warn "#### SVN checkout updated\n" unless $quiet;

  if( $setup_key && $commit_svn ) {
    run_cmd([qw(svn add -q), $conf_file]);
    run_cmd([qw(svn ci -m), 'adding site config', $conf_file]);
    warn "#### Committed site config\n" unless $quiet;
  }
  return;
}


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
  warn "#### Created HTML files\n" unless $quiet;

  unless( -e "$ROOT_PATH/sites/$domain_name/data/config/databases.yaml" ) {
    open my $d_fh, q(>), "$ROOT_PATH/sites/$domain_name/data/config/databases.yaml";
    print {$d_fh} $file_contents->{'databases.yaml'};
    close $d_fh;
  }
  ## Write the apache configuration file....
  unless( -e $conf_file ) {
    open my $conf_fh, q(>), $conf_file;
    print {$conf_fh} expand_parts($file_contents->{'apache.conf'});
    close $conf_fh;
  }
  ## use critic
  unless( -e "$ROOT_PATH/apache2/sites-enabled" ) {
    symlink $rel_conf_file, "$ROOT_PATH/apache2/sites-enabled/$domain_name.conf";
  }
  warn "#### Created config files\n" unless $quiet;
  return;
}

sub create_perl_files {
  return unless $name_space;
  ## Create lib directories, and insert boiler plate modules!
  ## no critic (RequireChecked)
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
  ## use critic
  warn "#### Created perl files\n" unless $quiet;
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
              'ApacheDir'      => "$setup_key.d" || 'core.d',
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

sub diedoc {
  my $msg = shift;
  die "\nERROR:\n  $msg",documentation(),"###### Command aborted ######\n\n";
}

sub documentation {
  return sprintf q(
Usage:
  create-site.pl {-h dir} \
                 {-d} {-b trunk|staging|live} {-c}   \
                 {-k setup_key} {-n namespace} {-q}  \
                 {-n} {-p 8xxx} {-r protocol://path} \
                 {-s protocol://path} {-t str} {domain_name}

Options:
  -b string [opt] - branch (trunk/staging/live)
                      [defaults to %s]
  -c        [opt] - DO NOT action the commit!
  -d        [opt] - dry run only - just dump the options!
  -h string [req] - key for htdocs files
  -k string [opt] - setup_key to create site in
  -n string [opt] - namespace for perl modules (and lc apache support)
  -q        [opt] - quiet - hide all output
  -r string [opt] - repository to get pagesmith-core from
                      [defaults to %s]
  -s string [opt] - root of local svn repository! if not set just creates
                    directory and checks out contents of pagesmith folders
  -t string [opt] - template name defaults to '%s'
  -v        [opt] - verbose - report output from shell scripts..

), $DEF_BRANCH, $DEF_SVN, $DEF_TEMPLATE;
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
