#!/usr/bin/perl -F'## no critic (UseUTF8 VersionVar)'

use strict;
use warnings;
use IPC::Run3 qw(run3);

## Define constants...

my $DIR_PERM       = 0755; ## no critic (LeadingZeros MagicNumbers)
my %VALID_BRANCHES = qw(trunk dev staging live live live);
my $OPTION_DEF = {
  'b' => ['s', 'trunk' ],                                # Branch
  'c' => [qw(- 1)],       # SVN co
  'd' => ['s', q() ],     # Domain (for web@ email address)
  'n' => [qw(+ 0)],       # Dry run
  'p' => [qw(s 8_000)],   # Port no
  'r' => ['s', 'http://websvn.europe.sanger.ac.uk/svn'], # External source
  's' => ['s', q()],      # SVN root - local
  'v' => [qw(+ 0)],       # Verbose
};
my %MOD_SYMLINKS = (
  'debian' => {
    '2.2' => [qw( alias.load apreq.load authz_host.load cgi.load dir.conf dir.load
                  env.load expires.load headers.load include.load mime.conf mime.load
                  jk.load perl.load proxy_http.load proxy.load rewrite.load
                  setenvif.load status.load)],
    '2.4' => [qw( alias.load apreq2.load authz_core.load authz_host.load
                  cgi.load dir.conf dir.load env.load expires.load filter.load
                  headers.load include.load jk.load mime.conf mime.load mpm_prefork.conf
                  mpm_prefork.load perl.load proxy_ftp.load proxy_http.load proxy.load
                  rewrite.load setenvif.load status.load )],
  },
  'redhat' => {
    '2.2' => [qw( alias.load apreq.load authz_host.load cgi.load dir.conf dir.load
                  env.load expires.load headers.load include.load log_config.load
                  mime.conf mime.load perl.load rewrite.load setenvif.load status.load
                  proxy_http.load proxy.load)],
    '2.4' => [qw( )],
  },
);

## First check to see if the user has passed anything... o/w return docs..
my $options = get_opts( $OPTION_DEF );
diedoc( 'Invalid branch' ) unless exists $VALID_BRANCHES{$options->{'b'}};
diedoc( 'Missing options/parameters' ) unless @ARGV;
my $setup_key   = shift @ARGV;
diedoc( 'Invalid setup key' ) unless $setup_key =~ m{\A\w+\Z}mxs;

my ( $linux_version, $apache_command,
     $module_path,   $apache_version ) = get_versions();

if( $options->{'s'} ) {
  diedoc( "Invalid SVN protocol/path: $options->{'s'}" )
    unless $options->{'s'} =~ m{\A(?:(?:svn(?:[+]\w+)?|https?)://[-\w]+|file://)/\w}mxs;
  diedoc( "Repository '$options->{'s'}/pagesmith/$setup_key-core' doesn't exists\n" )
    unless grep_out( ['svn', 'info', "$options->{'s'}/pagesmith/$setup_key-core"], 'Revision:[ ](\d+)' );
}

my $domain_name = exists $options->{'d'} ? $options->{'d'} : "$setup_key.org";
my $co_dir      = $VALID_BRANCHES{$options->{'b'}};

warn "Setting up with the following options:
  SVN repository:    $options->{'s'}
  Check in SVN:      $options->{'c'}
  Port no:           $options->{'p'}
  Domain:            $options->{'d'}
  Branch:            $options->{'b'}
  Externals from:    $options->{'r'}/pagesmith/pagesmith-core/$options->{'b'}
  Setup key:         $setup_key
    Repository:      $options->{'s'}/pagesmith/$setup_key-core
    Apache-dir:      $ENV{'PWD'}/www-$co_dir/apache2/$setup_key.d
    Core-directory:  $ENV{'PWD'}/www-$co_dir/core-$setup_key
" unless $options->{'q'};

die "\n###################### DRY RUN ONLY ######################\n\n" if $options->{'n'};

my @date           = gmtime;
my $date           = sprintf '%04d-%02d-%02d', $date[5]+1900,$date[4]+1,$date[3]; ## no critic (MagicNumbers)
my $user           = sprintf '%s (%s)',        @{[getpwuid $<]}[qw(0 6)];         ## no critic (PunctuationVars)
my $apache_sub_dir = "$setup_key.d";
my $file_contents  = {};

get_templates();
create_directories();
create_files();
create_symlinks();

if( $options->{'s'} ) {
  write_svn();
} else {
  checkout_core();
}

sub get_versions {
  my $distro =  -e '/usr/bin/dpkg'               ? 'debian'
             : -e '/usr/bin/rpm'                ? 'redhat'
             :                                    'unknown';
  my $ap_bin = -e '/usr/sbin/apache2'           ? 'apache2'
             : -e '/usr/sbin/httpd'             ? 'httpd'
             :                                    q();
  die "PANIC! - Unknown apache binary - can't find either apache2 or httpd\n"
    unless $ap_bin;
  my $mod_path = -e '/etc/apache2/mods-available' ? '/etc/apache2/mods-available'
               : -e '/etc/httpd/mods-available'   ? '/etc/httpd/mods-available'
               :                                    q();
## If can't get version then we will assume it's 2.4!
  my ($ap_ver) = grep_out ( ["/usr/sbin/$ap_bin",'-v'], 'Apache/(\d+[.]\d+)' );
  return ($distro,$ap_bin,$mod_path,$ap_ver);
}

sub get_templates {
  my $key;
  while(my $line =<DATA>) {
    if( $line =~ m{\A>>\s+(\S+)}mxs ) {
      $key = $1;
      $file_contents->{$key} = q();
      next;
    }
    $file_contents->{$key} .= $line;
  }
  warn "#### Templates retrieved\n" unless $options->{'q'};
  return;
}

sub create_directories {
  if( -d "www-$co_dir" ) { ## Directory already exists
    if( $options->{ 's' } ) {
      run_cmd( ['svn', 'up', "www-$co_dir"] );
    }
  } else {
    if( $options->{ 's' } ) {
      my $flag = grep_out( ['svn', 'info', "$options->{'s'}/pagesmith/$setup_key-core/$options->{'b'}"], 'Revision:[ ](\d+)' );
      run_cmd( ['svn', 'mkdir', '-m', "adding $options->{'b'} branch",
          "$options->{'s'}/pagesmith/$setup_key-core/$options->{'b'}" ] ) unless $flag;
      run_cmd( ['svn', 'co', "$options->{'s'}/pagesmith/$setup_key-core/$options->{'b'}", "www-$co_dir" ] );
    } else {
      mkdir "www-$co_dir", $DIR_PERM;
    }
  }
  my @dirs = qw(
    apache2
    apache2/sites-enabled
    apache2/mods-enabled
    apache2/MYDIR.d
    apache2/MYDIR.d/cache-conf
    apache2/MYDIR.d/general
    apache2/MYDIR.d/mods
    apache2/MYDIR.d/pagesmith
    apache2/MYDIR.d/sites-available
    apache2/MYDIR.d/workers
    apache2/other-included
    apache2/other-included/cache
    apache2/other-included/core
    apache2/other-included/pagesmith
    apache2/other-included/vhosts
    apache2/other-included/workers
    config
    config/data
    other-sites
    sites
    tmp
    core-MYDIR
    core-MYDIR/htdocs
    core-MYDIR/htdocs/assets
    core-MYDIR/htdocs/css
    core-MYDIR/htdocs/gfx
    core-MYDIR/htdocs/inc
    core-MYDIR/htdocs/js
    core-MYDIR/lib
    core-MYDIR/lib/Pagesmith
    core-MYDIR/lib/Pagesmith/Startup
    core-MYDIR/source
    core-MYDIR/utilities
  );

  foreach my $dir (@dirs) {
    $dir =~ s{UPPERMYDIR}{ucfirst $setup_key}mxseg;
    $dir =~ s{MYDIR}{$setup_key}mxseg;
    next if -d "www-$co_dir/$dir";
    mkdir "www-$co_dir/$dir", $DIR_PERM;
  }
  ## Create tmp path!
  my $root = $ENV{'PWD'};
  my $log_path = "$root/tmp/logs";
     $log_path = "/www/tmp$1/logs" if $root =~ m{^\/www(?:\/([-\w])+)?\Z}mxs;
  my @parts = split m{/}mxs, $log_path;
  shift @parts;
  my $d = q();
  foreach (@parts) {
    $d .= qq(/$_);
    mkdir $d, $DIR_PERM unless -d $d;
  }
  warn "#### Directories created\n" unless $options->{'q'};
  return;
}

sub create_files {
  ## no critic (RequireChecked)
  foreach my $file (keys %{$file_contents}) {
    ( my $path = $file ) =~ s{UPPERMYDIR}{ucfirst $setup_key}mxseg;
    $path =~ s{MYDIR}{$setup_key}mxseg;
    ## Check to see if file exists - if it does do not create!
    next if -e "www-$co_dir/$path";
    open my $fh, q(>), "www-$co_dir/$path";
    print {$fh} expand_parts( $file_contents->{$file} );
    close $fh;
  }
  ## Check to see if my-port exists  - if it does do not create!
  return if -e "www-$co_dir/my-port";
  open my $p_fh, q(>), "www-$co_dir/my-port";
  print {$p_fh} "$options->{'p'}\n";
  close $p_fh;
  ## use critic
  warn "#### Files created\n" unless $options->{'q'};
  return;
}


sub create_symlinks {
  if( $module_path ) {
    foreach ( @{$MOD_SYMLINKS{$linux_version}{$apache_version}} ) {
      ## Check to see if link exists if so do not create
      symlink "$module_path/$_", "www-$co_dir/apache2/mods-enabled";
    }
  }
  my %other_symlinks = qw(
    sites-enabled/000-default.conf                 ../core.d/sites-available/000-default.conf
    other-included/cache/local-filesystem.conf     ../../core.d/cache-conf/local-filesystem.conf
    other-included/cache/local-memcached.conf      ../../core.d/cache-conf/local-memcached.conf
    other-included/cache/local-mysql.conf          ../../core.d/cache-conf/local-mysql.conf

    other-included/core/apache-size-limit.conf     ../../core.d/mods/apache-size-limit.conf
    other-included/core/mime.conf                  ../../core.d/mods/mime.conf
    other-included/core/proxy.conf                 ../../core.d/mods/proxy.conf

    other-included/core/100-oracle-11.2.conf       ../../core.d/mods/100-oracle-11.2.conf
    other-included/core/jk.conf                    ../../core.d/mods/jk.conf
    other-included/core/MYDIR-server-status.conf   ../../MYDIR.d/mods/MYDIR-server-status.conf

    other-included/pagesmith/100-alt-template.conf ../../MYDIR.d/pagesmith/100-alt-template.conf
    other-included/pagesmith/200-alt-template.conf ../../core.d/pagesmith/200-alt-template.conf
    other-included/pagesmith/200-general-core.conf ../../core.d/pagesmith/200-general-core.conf
    other-included/pagesmith/800-general-core.conf ../../MYDIR.d/pagesmith/800-general-core.conf

    other-included/vhosts/general-vhost.conf       ../../MYDIR.d/general-vhost.conf
    other-included/vhosts/pagesmith-vhost.conf     ../../MYDIR.d/pagesmith-vhost.conf

    other-included/workers/workers-dev.properties  ../../MYDIR.d/workers/workers-dev.properties
    other-included/workers/workers-live.properties ../../MYDIR.d/workers/workers-live.properties
  );
  foreach my $k (keys %other_symlinks) {
    (my $v = $other_symlinks{$k}) =~ s{MYDIR}{$setup_key}mxseg;
    $k                            =~ s{MYDIR}{$setup_key}mxseg;
    ## Check to see if link exists if so do not create
    next if -e "www-$co_dir/apache2/$k";
    symlink $v, "www-$co_dir/apache2/$k";
  }
  warn "#### Sym-links created\n" unless $options->{'q'};
  return;
}

sub checkout_core {
  foreach my $dir (qw(fonts htdocs lib utilities apache2/core.d)) {
    if( -e "www-$co_dir/$dir" ) {
      run_cmd( ['svn', 'up', "www-$co_dir/$dir"] );
      warn "#### Core updated\n" unless $options->{'q'};
    } else {
      run_cmd( ['svn', 'co', "$options->{'r'}/pagesmith-core/$options->{'b'}/$dir",
        "www-$co_dir/$dir"] );
      warn "#### Core checkedout\n" unless $options->{'q'};
    }
  }
  ## use critic
  return;
}

sub write_svn {
  run_cmd( [ qw(svn add -q), "www-$co_dir/core-$setup_key",
    map {"www-$co_dir/$_"} qw(apache2 config other-sites sites tmp)]);
  unless( grep_out([qw(svn pg svn:externals), "www-$co_dir/apache2"]) ) {
    run_cmd( [ qw(svn ps svn:externals),
      "core.d $options->{'r'}/pagesmith-core/$options->{'b'}/apache2/core.d",
      "www-$co_dir/apache2"] );
  }
  unless( grep_out([qw(svn pg svn:externals), "www-$co_dir"]) ) {
    run_cmd( [qw(svn ps svn:externals), "fonts     $options->{'r'}/pagesmith-core/$options->{'b'}/fonts
htdocs    $options->{'r'}/pagesmith-core/$options->{'b'}/htdocs
lib       $options->{'r'}/pagesmith-core/$options->{'b'}/lib
utilities $options->{'r'}/pagesmith-core/$options->{'b'}/utilities", "www-$co_dir"]);
  }
  foreach my $dir (qw(
    other-sites
    sites
    tmp
    apache2/mods-enabled
    apache2/sites-enabled
    apache2/other-included/pagesmith
    apache2/other-included/cache
    apache2/other-included/vhosts
    apache2/other-included/core
    apache2/other-included/workers
  )) {
    next if grep_out([qw(svn pg svn:ignore), "www-$co_dir/$dir"]);
    run_cmd( [qw(svn ps svn:ignore '*'), "www-$co_dir/$dir"] );
  }
  run_cmd( [qw(svn ps svn:ignore 'my-port'), "www-$co_dir"])
    unless grep_out([qw(svn pg svn:ignore), "www-$co_dir"]);
  my $commits = grep_out([qw(svn log), "www-$co_dir"], '----------' );
  $commits--;
  warn "#### SVN externals etc setup\n" unless $options->{'q'};
  run_cmd([qw(svn ci -m),
    $commits == 1 ? 'creating initial server structure'
                  : 'patching server structure',
    "www-$co_dir"]) if $options->{'c'};
  warn "#### SVN repository committed\n" if $options->{'c'} && !$options->{'q'};
  run_cmd([qw(svn up), "www-$co_dir"]);
  warn "#### SVN checkout updated\n" unless $options->{'q'};
  return;
}

sub expand_parts {
  my $string = shift;
  (my $shortened_domain_name = $domain_name ) =~ s{\Awww[.]}{}mxs;
  ## no critic (InterpolationOfMetachars)
  my $bptemplate = '## Author         : %s
## Maintainer     : %s
## Created        : %s
## Last commit by : $Author $
## Last modified  : $Date $
## Revision       : $Revision $
## Repository URL : $HeadURL $';
  my $map = { 'ShortDomain'    => $shortened_domain_name,
              'MyDir'          => $setup_key,
              'UpperMyDir'     => ucfirst $setup_key,
              'Author'         => $user,
              'SvnID'          => '$Id $',
              'BoilerPlate'    => sprintf $bptemplate, $user, $user, $date,
            };
  ## use critic
  $string =~ s{[{][{](\w+)[}][}]}{$map->{$1}||"YARG{{$1}}"}mxseg;
  return $string;
}

sub diedoc {
  my $msg = shift;
  die "\nERROR:\n  $msg",documentation(),"###### Command aborted ######\n\n";
}

sub documentation {
  return sprintf q(
Usage:
  create-server.pl {-b trunk|staging|live} {-c} {-d mydomain.org} \
                   {-n} {-p 8xxx} {-q} {-r protocol://path} \
                   {-s protocol://path} {-v} {setupkey}

Options:
  -b string [opt] - branch (trunk/staging/live)
                      [defaults to %s]
  -c        [opt] - DO NOT action the commit!
  -d string [opt] - domain name for admin email...
                      [defaults to {setupkey}.org]
  -n              - dry run only - just dump the options!
  -p number [opt] - port under which apache will run
                      [defaults to %s]
  -q              - quiet - hide all output
  -r string [opt] - repository to get pagesmith-core from
                      [defaults to %s]
  -s string [opt] - root of local svn repository! if not set just creates
                    directory and checks out contents of pagesmith folders
  -v              - verbose - report output from shell scripts..

Note:
  {setupkey} is used to generate namespace of packages, core, apache site
  folder details and includes
), map { $OPTION_DEF->{$_}[1] } qw(b p r);
}

## Support functions!
sub get_opts {
  my $def = shift;
  my $values = {map { ( $_ => $def->{$_}[1] ) } keys %{$def}};
  while( @ARGV ) {
    my $k = shift @ARGV;
    if( $k =~ m{-(\w+)}mxs ) {
      my $opt = $1;
      if( exists $def->{$opt} ) {
        if($def->{$opt}[0] eq 's') {
          $values->{ $opt } = shift @ARGV;
        } elsif($def->{$opt}[0] eq q(-)) {
          $values->{ $opt } = 0;
        } else {
          $values->{ $opt } = 1;
        }
      } else {
        die "Unknown option $k\n",documentation()."\n";
      }
    } else {
      unshift @ARGV, $k;
      last;
    }
  }
  return $values;
}

sub grep_out {
  my ( $command_ref, $match, $input ) = @_;
  my $res = run_cmd( $command_ref, $input );
  return unless $res->{'success'};
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
  if( $options->{'v'} ) {
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

1;

__END__
>> apache2/00-readme.conf
#----------------------------------------------------------------------#
# Setting up the configuration files for the Apache instance           #
#----------------------------------------------------------------------#
#                                                                      #
# You should have 5 directories in your route repository               #
#                                                                      #
#----------------------------------------------------------------------#
# Folders containing configuration files                               #
#----------------------------------------------------------------------#
# core.d         : this contains all the core configuration for        #
#                : pagesmith and general sites                         #
#                : [ you should include this directory with            #
#                :   svn propset svn:externals on the apache2 dir ]    #
# {{MyDir}}.d : this contains all the local configurations for your #
#                : server which are generic across all sites, plus     #
#                : modifications to core module configurations         #
#----------------------------------------------------------------------#
# Three folders to contain symlinks to files in core.d and "local".d   #
#----------------------------------------------------------------------#
# mods-enabled   : links to core modules                               #
# sites-enabled  : links to site files from *.d/sites-available        #
# other-included : links to files in core.d/"local".d that modify      #
#                : general configurations...                           #
#----------------------------------------------------------------------#

>> apache2/other-included/00-readme.conf
# * cache      - put in sym-links to the three config files for memcached, SQL & file system
# * core       - put in sym-links to general modifications for modules / core modules
# * pagesmith  - put in sym-links to extra pagesmith configuration modules
# * vhosts     - put in here configurartion files that are included in multiple vhosts
# * workers    - put in sym-links to the dev/live workers files

>> apache2/MYDIR.d/pagesmith-vhost.conf
#----------------------------------------------------------------------#
# This file should be included in all Pagesmith vhost configurations   #
#----------------------------------------------------------------------#

Include core.d/general/600-vhost-core.conf
Include core.d/pagesmith/700-vhost-core.conf
Include {{MyDir}}.d/general/800-vhost-{{MyDir}}.conf
Include {{MyDir}}.d/pagesmith/900-vhost-{{MyDir}}.conf

>> apache2/MYDIR.d/general-vhost.conf
#----------------------------------------------------------------------#
# This file should be included in all website vhost configurations     #
#----------------------------------------------------------------------#

Include core.d/general/600-vhost-core.conf
Include {{MyDir}}.d/general/800-vhost-{{MyDir}}.conf

>> apache2/MYDIR.d/mods/MYDIR-apache-site-limit.conf
#----------------------------------------------------------------------#
# This file may be symlinked into other-included/core and so included  #
# directly in main httpd.conf                                          #
# * Sets security up for server-status if require direct access to it  #
#----------------------------------------------------------------------#
<IfDefine !PAGESMITH_PROFILE>
  PerlLoadModule        Apache2::SizeLimit
  <Perl>
    Apache2::SizeLimit->set_max_process_size(  800_000 );
    Apache2::SizeLimit->set_max_unshared_size( 200_000 );
    Apache2::SizeLimit->set_min_shared_size(    20_000 );
  </Perl>
  PerlCleanupHandler    Apache2::SizeLimit
</IfDefine>

>> apache2/MYDIR.d/mods/MYDIR-server-status.conf
#----------------------------------------------------------------------#
# This file may be symlinked into other-included/core and so included  #
# directly in main httpd.conf                                          #
# * Sets security up for server-status if require direct access to it  #
#----------------------------------------------------------------------#

<IfModule mod_status.c>
ExtendedStatus On
<Location /server-status>
  SetHandler server-status
  <IfDefine !PAGESMITH_APACHE_24>
    Order deny,allow
    Deny from all
    # Allow from .internal.{{ShortDomain}}
  </IfDefine>
  <IfDefine PAGESMITH_APACHE_24>
    # Require host .internal.{{ShortDomain}}
  </IfDefine>
</Location>
</IfModule>

>> apache2/MYDIR.d/pagesmith/100-alt-template.conf
#----------------------------------------------------------------------#
# This file is included in main httpd.conf                             #
# * It defines any browser strings which will force and alternative    #
#   template - useful to remove fluff from a page which is being       #
#   indexed by a search engine                                         #
#----------------------------------------------------------------------#

<IfModule mod_setenvif.c>
  BrowserMatch ^My/Nutch-1.                  X-Pagesmith-searchengine
</IfModule>

>> apache2/MYDIR.d/pagesmith/800-general-core.conf
#----------------------------------------------------------------------#
# This file is included in main httpd.conf                             #
# * Initially everything is commented out - uncommenting blocks will   #
#   define a number of Pagesmith configurations related to Proxy_URLs  #
#   and the QR code                                                    #
# * Also can require an additional startup script which can include    #
#   additional library paths etc                                       #
#----------------------------------------------------------------------#

# PerlConfigRequire        ${PAGESMITH_SERVER_PATH}/core-{{MyDir}}/lib/Pagesmith/Startup/{{UpperMyDir}}Core.pm

# Pagesmith_Proxy_URL      http://my-webcache:3128/
# Pagesmith_Proxy_NoProxy  .internal.{{ShortDomain}}

# PerlSetVar      X_Pagesmith_QrURL        http://q.{{ShortDomain}}/

# <IfDefine PAGESMITH_DEV>
#   PerlSetVar      X_Pagesmith_QrURL        http://r.{{ShortDomain}}/
# </IfDefine>

>> apache2/MYDIR.d/cache-conf/cache-mysql.conf
#----------------------------------------------------------------------#
# This file may be symlinked into other-included/cache and so included #
# directly in main httpd.conf                                          #
# * Configuration for the SQL backed caching server!                   #
#----------------------------------------------------------------------#

Pagesmith_SQL_DSN          dbi:mysql:webcache_live:mysql-server:3306
Pagesmith_SQL_User         webcache_rw
Pagesmith_SQL_Pass         webcache_rw
Pagesmith_SQL_Option       RaiseError=1
Pagesmith_SQL_Option       PrintError=1
Pagesmith_SQL_Option       LongReadLen=10000000
Pagesmith_SQL_Option       mysql_enable_utf8=1

>> apache2/MYDIR.d/cache-conf/cache-memcached.conf
#----------------------------------------------------------------------#
# This file may be symlinked into other-included/cache and so included #
# directly in main httpd.conf                                          #
# * Configuration for the memcached caching server!                    #
#----------------------------------------------------------------------#

Pagesmith_MC_Server   555.555.555.555:11211,1
Pagesmith_MC_Server   555.555.555.555:11211,1
Pagesmith_MC_Option   debug=0 compress_threshold=10000000000

>> apache2/MYDIR.d/general/800-vhost-MYDIR.conf
#----------------------------------------------------------------------#
# This file is included in virtualhost for all websites                #
#----------------------------------------------------------------------#

ServerAdmin web@{{ShortDomain}}

>> core-MYDIR/lib/Pagesmith/Startup/UPPERMYDIRCore.pm
package Pagesmith::Startup::{{UpperMyDir}}Core;

## Apache start-up script to preload in a number of modules
## required for this specific pagesmith setup to spee up
## process of producing children and to minimise amount of
## shared memory.

{{BoilerPlate}}

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use File::Basename qw(dirname);
use Cwd qw(abs_path);

BEGIN { unless( exists $ENV{q(SINGLE_LIB_DIR)} && $ENV{q(SINGLE_LIB_DIR)} ) {
  my $dir = dirname(dirname(dirname(abs_path(__FILE__))));
  if( -e $dir ) {
    unshift @INC, $dir;
    $ENV{'PERL5LIB'}||=q();
    $ENV{'PERL5LIB'} = qq($dir:$ENV{'PERL5LIB'}); ## no critic (LocalizedPunctuationVars)
  }
  $dir = dirname($dir).'/ext-lib';
  if( -e $dir ) {
    unshift @INC, $dir;
    $ENV{'PERL5LIB'}||=q();
    $ENV{'PERL5LIB'} = qq($dir:$ENV{'PERL5LIB'}); ## no critic (LocalizedPunctuationVars)
  }
}}

## Now we need to include here a list of preloaded use statements if required!

# use XYZ::ZYX;

1;
>> apache2/MYDIR.d/pagesmith/900-vhost-MYDIR.conf
#----------------------------------------------------------------------#
# This file is included in virtualhost for pagesmith websites          #
#----------------------------------------------------------------------#

## Realm for which development tools are visible!

# PerlSetVar  X_Pagesmith_DevelRealm   #realm#

## Authentication server configuration

# PerlSetVar  X_Pagesmith_AuthServer      http://www.{{ShortDomain}}
# PerlSetVar  X_Pagesmith_AuthKey         auth_key
# PerlSetVar  X_Pagesmith_AuthToken       auth_token
# PerlSetVar  X_Pagesmith_AuthSecret      auth_secret
# PerlSetVar  X_Pagesmith_AuthExpireCount 7
# PerlSetVar  X_Pagesmith_AuthExpireUnit  day
# PerlSetVar  X_Pagesmith_CookieToken     cookie_token

## Internal services administration

# PerlSetVar  X_Pagesmith_LdapURL         ldap.{{ShortDomain}}

>> apache2/MYDIR.d/workers/workers-dev.properties
#----------------------------------------------------------------------#
# This is the workers file for dev setup                               #
#----------------------------------------------------------------------#
##
#worker.list=myworker,myworker_1,myworker_2

#worker.myworker_1.port=
#worker.myworker_1.host=
#worker.myworker_1.type=ajp13
#worker.myworker_1.lbfactor=1
#worker.myworker_1.sticky_session=1
#worker.myworker_1.socket_connect_timeout=5000

#worker.myworker_2.port=
#worker.myworker_2.host=
#worker.myworker_2.type=ajp13
#worker.myworker_2.lbfactor=1
#worker.myworker_2.sticky_session=1
#worker.myworker_2.socket_connect_timeout=5000

# Define the Tomcat LB worker
#worker.myworker.type=lb
#worker.myworker.balance_workers=myworker_1,myworker_2

>> apache2/MYDIR.d/workers/workers-live.properties
#----------------------------------------------------------------------#
# This is the workers file for live setup                              #
#----------------------------------------------------------------------#
##
#worker.list=myworker,myworker_1,myworker_2

#worker.myworker_1.port=
#worker.myworker_1.host=
#worker.myworker_1.type=ajp13
#worker.myworker_1.lbfactor=1
#worker.myworker_1.sticky_session=1
#worker.myworker_1.socket_connect_timeout=5000

#worker.myworker_2.port=
#worker.myworker_2.host=
#worker.myworker_2.type=ajp13
#worker.myworker_2.lbfactor=1
#worker.myworker_2.sticky_session=1
#worker.myworker_2.socket_connect_timeout=5000

# Define the Tomcat LB worker
#worker.myworker.type=lb
#worker.myworker.balance_workers=myworker_1,myworker_2

>> config/data/site-templates.txt
!! NOTES!
########################################################################
########################################################################
## From here on in this file is used to generate site related         ##
## files..                                                            ##
##  * Stubs for css, js, databases.yaml;                              ##
##  * virtual host config for site                                    ##
##  * perl libraries                                                  ##
##  * static content index/contact/cookiespolicy/legal                ##
##  * templates (hnav/nav)                                            ##
########################################################################
########################################################################
!! css
/* Place here any CSS which you want to over-ride the standard CSS */

/* Should define, colours, image dimensions,
   Plus site specific markup!

   For specific functionality create new CSS files for that in this
   directory and include them in the template!
 */

!! js
/* Place here any JS which you want to extended the standard JS */

/* Most JS can be achieved by including CSS/JS from the core,
   especially for microsites,

   More specific functionality should probably be put in better
   named files in this directory! and include them in tht template
 */
!! databases.yaml
---
default:
dev:

!! apache.conf
# PerlConfigRequire ${PAGESMITH_SERVER_PATH}/sites/[[DomainName]]/lib/Pagesmith/Startup/[[NameSpace]].pm

<VirtualHost *:*>
  UseCanonicalName On
  ServerName   [[DomainName]]
  ServerAlias  dev.[[ShortDomainName]]
  ServerAlias  staging.[[ShortDomainName]]

  PerlSetVar   X_Pagesmith_Domain       [[DomainName]]

  DocumentRoot ${PAGESMITH_SERVER_PATH}/sites/[[DomainName]]/htdocs

#  PerlSetVar   X_Pagesmith_RequiredDiv  panel
#  PerlSetVar   X_Pagesmith_QrEnabled    0
#  PerlSetVar   X_Pagesmith_Staging      true
#  PerlSetVar   X_Pagesmith_Editable     all

#  PerlSetVar   X_Pagesmith_NameSpace    [[NameSpace]]

  Include      [[ApacheDir]]/pagesmith-vhost.conf

##----------------------------------------------------------------------
## Additional handlers... - this maps /mydomain/XX_YY to Pagesmith::Action::MyDomain::XX::YY

#  <Location ~ "^/[[LowerNameSpace]]/">
#    SetHandler modperl
#    PerlResponseHandler Pagesmith::Apache::Action::MyDomain
#  </Location>

##----------------------------------------------------------------------
## Access hanndler

#  <Location ~ "^/secret_data/">
#    SetHandler modperl
#    PerlAccessHandler Pagesmith::Apache::Access::Config
#    PerlSetVar X_Pagesmith_AuthGroup my_secret_group
#  </Location>

##----------------------------------------------------------------------
## Java proxy set ups...
##----------------------------------------------------------------------
## Make sure that for any action which generates HTML that you add the
## pattern to the PerlOutputFilterHandler's below

#  <IfModule mod_jk.c>
#    JkMount       /path_1/*   myworker
#    JkMount       /path_2/*   myworker_1
#    <IfDefine PAGESMITH_DEV>
#      JkMount       /path_3/* myworker_2
#    </IfDefine>
#    <IfDefine !PAGESMITH_DEV>
#      JkMount       /path_3/* myworker_1
#    </IfDefine>
#    ## Note we have to formally add the page wrapper!
#    <Location ~ "^/path_(1|3)/.*">
#      ## /path_2/ is non-html output!
#      PerlOutputFilterHandler Pagesmith::Apache::Decorate
#    </Location>
#  </IfModule>

##----------------------------------------------------------------------
## Non-java proxy set ups...
##----------------------------------------------------------------------
## Make sure that for any action which generates HTML that you add the
## pattern to the PerlOutputFilterHandler's below


#  <IfModule mod_proxy.c>
#    ProxyPass        /path_4/      http://myother-server.mydomain.org/path_4/
#    ProxyPassReverse /path_4/      http://myother-server.mydomain.org/path_4/
#    ProxyPass        /path_5/      http://myother-server.mydomain.org/path_5/
#    ProxyPassReverse /path_5/      http://myother-server.mydomain.org/path_5/
#    <Location ~ "^/path_(4)/.*">
#      ## /path_5/ is non-html output!
#      PerlOutputFilterHandler Pagesmith::Apache::Decorate
#    </Location>
#  </IfModule>

</VirtualHost>

!! Startup
package Pagesmith::Startup::[[NameSpace]];

## Apache start-up script to include site specific lib
## directories, and preload any modules required by the
## system - to speed up process of producing children
## and to maximise amount of shared memory.

[[BoilerPlate]]

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use File::Basename qw(dirname);
use Cwd qw(abs_path);

BEGIN { unless( exists $ENV{q(SINGLE_LIB_DIR)} && $ENV{q(SINGLE_LIB_DIR)} ) {
  my $dir = dirname(dirname(dirname(abs_path(__FILE__))));
  my $has_cgi = -d dirname($dir).'/cgi';
  if( -d $dir ) {
    unshift @INC, $dir;
    $ENV{'PERL5LIB'} = qq($dir:$ENV{'PERL5LIB'}) if $has_cgi; ## no critic (LocalizedPunctuationVars)
  }
  $dir = dirname($dir).'/ext-lib';
  if( -d $dir ) {
    unshift @INC, $dir;
    $ENV{'PERL5LIB'} = qq($dir:$ENV{'PERL5LIB'}) if $has_cgi; ## no critic (LocalizedPunctuationVars)
  }
}}

## Now we need to include here a list of preloaded use statements if required!

# use Pagesmith::Action::[[NameSpace]]
# use Pagesmith::Component::[[NameSpace]]
# use Pagesmith::Support::[[NameSpace]]
# use Pagesmith::Apache::Action::[[NameSpace]]

1;
!! Support
package Pagesmith::Support::[[NameSpace]];

## Put functions here that are shared between Actions and Components

[[BoilerPlate]]

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

1;
!! Action
package Pagesmith::Action::[[NameSpace]];

## Put functions here that are shared between all Actions

[[BoilerPlate]]

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action Pagesmith::Support::[[NameSpace]]);

sub run {
  my $self = shift;
  return $self->no_content;
}

1;

!! Component
package Pagesmith::Component::[[NameSpace]];

## Put functions here that are shared between all Components

[[BoilerPlate]]

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action Pagesmith::Support::[[NameSpace]]);

sub execute {
  my $self = shift;
  return q();
}

1;
!! Apache/Action
package Pagesmith::Apache::Action::[[NameSpace]];

## Apache handler for [[NameSpace]] action classes for [[DomainName]]

[[BoilerPlate]]

use strict;
use warnings;
use utf8;

use version qw(qv);our $VERSION = qv('0.1.0');

use Pagesmith::Apache::Action qw(my_handler);

sub handler {
  my $r = shift;
  # return($path_munger_sub_ref,$request)
  # see Pagesmith::Action::_handler to find out how this works
  # briefly:  munges the url path using the sub {} defined here
  # to get the action module
  # then calls its run() method and returns a status value

  return my_handler(
    sub {
      my ( $apache_r, $path_info ) = @_;
      if( $path_info->[0] eq '[[LowerNameSpace]]' ) {
        shift @{$path_info};
        if( @{$path_info} ) {
          $path_info->[0] = '[[NameSpace]]_'.$path_info->[0];
        } else {
          unshift @{$path_info}, '[[NameSpace]]';
        }
      }
      return;
    },
    $r,
  );
}

1;
!! index.html
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>

<head>
  <meta name="svn-id" content="[[SvnID]]" />
  <meta name="author" content="[[Author]]" />
  <title>Home page</title>
</head>

<body>
<p>Put content here!</p>
</body>
</html>
!! cookiespolicy.html
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>

<head>
  <meta name="svn-id" content="[[SvnID]]" />
  <meta name="author" content="[[Author]]" />
  <title>Cookie Policy</title>
</head>

<h2>Cookies Policy</h2>
<p>Information that the we collect from you.</p>
<h4>What is a cookie?</h4>
  <p>A cookie (sometimes known as web cookie, browser cookie or html cookie) is a small amount of data (&lt;4Kb) that is sent to your computer or web-enabled device (hereafter referred to as a "device") browser from a website's server.  The cookie can include a unique identifier within it.</p>
  <h4>Where does the cookie go?</h4>
  <p>The cookie is stored on your device's hard drive (this is often called "setting a cookie"). Each website that wishes to send you its cookie can only do so if your device's web browser preferences, that you can set personally, are set to allow this. To protect your privacy your device browser only permits a website to access the cookies it has sent to you, not the cookies sent to you by other websites. Many websites set one or more cookies to track online traffic through their website.</p>
  <p>Wellcome Trust Sanger Institute hosted websites, set cookies to store information about your:</p>
  <ol>
    <li>online preferences that allow us to tailor our websites to your data requirements</li>
    <li>access rights i.e. your ability to login to restricted services and the duration of that login</li>
    <li>Anonymous user tracking across our sites.</li>
  </ol>

  <p>Users can set their device browsers to accept all cookies, to notify them when a cookie is issued, or not to receive cookies at any time. The last of these means that certain personalised features cannot then be provided to that user and accordingly they may not be able to take full advantage of all of the website's features. Each browser is different, so check the "Help" menu of your browser to learn how to change your cookie preferences.</p>
  <p>During the course of any visit to a Sanger Institute hosted website, the pages you see, along with a cookie, are downloaded to your device. This enables our website publishers to find out whether the device (and its user) has visited the website before. This is done on repeat visits by checking to see, and finding, the cookie left there on the last visit.</p>
  <h4>How do we use cookies?</h4>
    <p>There are three main uses:-</p>
    <ul>
      <li>Information supplied by cookies helps us to anonymously analyse the access patterns of visitors and helps us provide a better user experience.</li>
      <li>Web site usage. Many of the research funding agencies that provide funding for the Sanger Institute's research require annual reports to determine how often websites are visited by both academic and lay visitors.</li>
      <li>State information e.g. authentication or information about the user session.</li>
    </ul>
    <h4>Third Party Cookies and Flash Cookies</h4>
    <p>We do not use information contained in cookies created by a third party or Flash cookies.</p>

    <h4>Our cookies and how to reject cookies?</h4>
    <p>A list of the cookies that our hosted websites set (and what each is used for) together with ways to minimise the number of cookies you receive can be found below.</p>
    <p><em>i. List of the our main cookies</em></p>
    <p>This is a list of the main cookies set by us, and what each is used for.</p>
  <table class="sorted-table filter narrow-sorted before" summary="cookies">
    <thead>
      <tr>
        <th style="width:25%">Cookie Name</th>
        <th style="width:35%">Purpose</th>
        <th style="width:20%">Criteria</th>
        <th style="width:20%">Domains cookie set</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>PageSmith</td>
        <td>Set Ajax enabled, font size</td>
        <td>Strictly necessary</td>
        <td>All pagesmith sites</td>
      </tr>
      <tr>
        <td>Pagesmith_User</td>
        <td>Login session id</td>
        <td>Strictly necessary</td>
        <td>All pagesmith sites which have user login</td>
      </tr>
    </tbody>
  </table>
  <p>These are used to provide session 'state' information i.e. authentication and user session identification but not for data collection. Their usage is described on the host website in question.</p>

  <p><em>ii. How to control and delete cookies</em></p>
  <p>The Sanger Institute does not use cookies to collect personally identifiable information about you. However, if you wish to restrict or block the cookies which are set by our websites, or indeed any other website, you can do this through your browser settings. The Help function within your browser should tell you how.</p>
  <p>Alternatively, you may wish to visit <a href="http://www.aboutcookies.org">www.aboutcookies.org</a> which contains comprehensive information on how to do this on a wide variety of browsers. You will also find details on how to delete cookies from your computer as well as more general information about cookies. For information on how to do this on the browser of your mobile phone you will need to refer to your handset manual.</p>
  <p>Sanger Institute-hosted websites honour browsers that have the "do not track" (DNT) feature set.  Only a limited number of browsers support DNT currently,</p>
  <ol>
    <li>firefox 5+</li>
    <li>IE 9</li>
    <li>Safari on Lion.</li>
  </ol>
  <p>Further information can be found at <a href="http://donottrack.us/">http://donottrack.us/</a></p>
  <p>For Chrome there is an "<a href="https://chrome.google.com/webstore/detail/hhnjdplhmcnkiecampfdgfjilccfpfoe">Extension</a>" for this browser which can be installed.</p>
  <p>Please be aware that restricting cookies may impact on the functionality of the Sanger Institute website.</p>

  <p><em>iii. Cookies set by Third Party sites</em></p>
  <p>To support our research and public engagement, we may embed photos and/or video content from websites such as YouTube and Flickr. When you visit a page with content embedded as above, you may be presented with cookies from these websites. The Sanger Institute does not control the dissemination of these cookies.&#160;You should check the relevant third party website for more information about these.</p>

  <h4>How to tell us about changes</h4>
  <p>If you have any questions about data protection or require further information, please email <% Email web@[[ShortDomainName]] %></p>

</body>
</html>
!! contact.html
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>

<head>
  <meta name="svn-id" content="[[SvnID]]" />
  <meta name="author" content="[[Author]]" />
  <title>Contact Us</title>
</head>
<body>
  <h2>Contact Us</h2>
  <p>To contact us please email <% Email web@[[ShortDomainName]] %></p>
</body>
</html>
!! legal.html
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>

<head>
  <meta name="svn-id" content="[[SvnID]]" />
  <meta name="author" content="[[Author]]" />
  <title>Legal</title>
</head>

<body>
<h2>Legal</h2>
  <p>
    Access to and use of this site is subject to the following conditions:
  </p>
  <ol>
    <li>you accept the following Terms and Conditions, which take effect on the date of your first use of the site;</li>
    <li>We reserve the right to change the Terms and Conditions at any time. </li>
  </ol>
  <p>
    We endeavour to make this site as useful as possible to our visitors. Please use the contact page if you have queries, want
    to suggest improvements or report deficiencies.
  </p>
  <h3>Terms and conditions</h3>
  <p>
    The material contained in this website is provided for general purposes only and, as
    such, should not be considered as a substitute for advice covering any specific situation.
  </p>
  <p>
    Although we make reasonable efforts to ensure that the information is accurate and up to date at the time of inclusion, the
    Sanger Institute accepts no responsibility for loss arising from reliance on information contained in this site or other
    sites that may be linked to from our site.
  </p>
  <p>
    We do not endorse or recommend commercial products, processes or services and no such conclusion should
    be drawn from content provided in or linked from this website.
  </p>
  <p>
    Links to other internet sites are provided only for the convenience of users of our
    website. We are not responsible for the content of external internet sites.
  </p>
  <p>
    We endeavour to maintain this site but do not warrant that the site will be continuously available or
    error-free, nor does we that this service will be free of defects or bugs or malicious software
    or code.
  </p>
  <p>
    Neither us nor those contributing to the site shall be liable for any losses or damage that may result
    from use of the website as a consequence of any inaccuracies in, or any omissions from, the information, which it may
    contain.
  </p>
  <p>
    We reserve the right to make changes to this website at any time without notice.
  </p>
  <p>
    You agree to use this site only for lawful purposes.
  </p>
  <p>
    If you do not accept these Terms and Conditions in full, you will cease using this site immediately.
  </p>

  <h3>Privacy Policy</h3>
  <p>
    Our policy is simple: we will not share your information with third parties without users'
    consent.
  </p>
  <p>
    We will however store the following information for purpose of evaluating our site: the domain name from
    which you access the Internet, the date and time you access our site, terms entered into our search engine, and the
    Internet address of the website from which you direct-linked to our site. This information is used to measure the number of
    visitors to the various sections of our site and to help us make our site more useful to our visitors. Other information
    collected during the course of your usage of the site, such as pages visited, may be collected in server log files and used
    for statistical analysis of traffic patterns.
  </p>
  <p>
    From time to time, we may ask for further information about you (such as your name, job title, postal
    address, telephone, fax number and e-mail address) as part of online surveys/services. If you provide us with your
    information we will only use it for the purposes you designate.
  </p>
  <p>
    Your information will be used to enable us to improve our website. Your data may be provided to a third party for
    evaluation purposes, not commercial exploitation.
  </p>
  <p>
    If you choose to provide us with personal information, as in an e-mail message or online form, we will
    use this information to respond to your request. There might be times when your e-mail is forwarded within our organisation
    to employees who are better able to assist you. We will not retain this information for longer than is necessary.
  </p>
  <h3>Use of Cookies</h3>
  <p>
    Customisation of this website requires that our server can identify the computer and web browser that requests data over a
    period of time. To do this, a small file is saved on the user's computer. This file contains no personal data, only an
    encrypted numeric identifier. Visitors' page settings are stored in a user database against this identifier, making it
    possible for us to save your settings without storing any other information about you.
  </p>
  <h3>Additional information held in user accounts</h3>
  <p>
    Of necessity, all user accounts are accessible to our web database administrators. However
    passwords are stored in one-way encrypted format and cannot be retrieved by these administrators. This does not affect your
    statutory rights.
  </p>
  <h3>Creative Commons Licence</h3>
  <p>
    Online content created and hosted by us is, unless otherwise stated, licensed under a
    Creative Commons <a href="http://creativecommons.org/licenses/by-nc-nd/2.5/">Attribution-NonCommercial-NoDerivs 2.5
    License</a>. <a href="http://creativecommons.org/licenses/by-nc-nd/2.5/">The terms of the license can be found here.</a>
  </p>
  <p>
    This work is licensed under a Creative Commons Licence.
  </p>
  <h3>General</h3>
  <p>
    Where possible, images on our sites are credited to their source and copyright owners on the relevant page.
  </p>
  <h3>Further information</h3>
  <p>
    For further information about image sources and permission to reproduce, please contact <% Email web@[[ShortDomainName]] %>
  </p>
</body>
</html>
!! hnav-template
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-gb">
<head>
  <meta name="author" content="[[Author]]" />
  <meta name="template-svn-id" content="[[SvnID]]" />
  <link rel="Shortcut Icon" href="/[[HtdocsSubDir]]/gfx/[[HtdocsSubDir]]_ico.png" type="image/png" />
  <title>[[ShortDomainName]] - <%= h:title %></title>
  <link rel="stylesheet" type="text/css" href="
    /core/css/pagesmith/css-reset.css
    /core/css/pagesmith/tables.css

    /core/css/templates/general.css
    /core/css/templates/page-frame.css
    /core/css/templates/width-960.css

    /core/css/templates/top/nav.css

    /core/css/developer/error-messages.css
    /core/css/developer/developer-panel.css

    /apcdr/css/apcdr.css

    /[[HtdocsSubDir]]/css/[[HtdocsSubDir]].css
  " />
<!--[if lt IE 9]>
  <link rel="stylesheet" type="text/css" href="
    /core/css/templates/ie.css
    /core/css/templates/top/ie.css
  " />
<![endif]-->
</head>
<body>
  <div id="wrap">
    <a href="/"><img src="/[[HtdocsSubDir]]/gfx/[[HtdocsSubDir]]_logo.png" alt="[[ShortDomainName]]" /></a>
    <h1><a href="/">[[ShortDomainName]]</a></h1>
    <div id="hnav">
      <ul>
        <li><a href="/">About</a></li>
        <li>&nbsp;</li>
        <li>&nbsp;</li>
        <li>&nbsp;</li>
        <li><a href="/contact.html">Contacts</a></li>
      </ul>
    </div>
    <div id="content">
      <% content %>
    </div>
    <div class="x">&nbsp;</div>
  </div>
  <p id="inst">
    <span id="tsandcs">
    <a href="/cookiespolicy.html">Cookies policy</a> | <a href="/legal.html">Terms &amp; Conditions.</a>
    </span>
    This site is hosted by the XXX
  </p>
  <%~ Developer_Messages -severity all -stack_trace 5 -stack_trace_level warn ~%>
  <script type="text/javascript" src="
    /core/js/non-jquery/stripes.js
    /[[HtdocsSubDir]]/js/[[HtdocsSubDir]].js
  " ></script>

</body>
</html>
!! nav-template
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-gb">
<head>
  <meta name="author" content="[[Author]]" />
  <meta name="template-svn-id" content="[[SvnID]]" />
  <link rel="Shortcut Icon" href="/[[HtdocsSubDir]]/gfx/[[HtdocsSubDir]]_ico.png" type="image/png" />
  <title>[[ShortDomainName]] - <%= h:title %></title>
  <link rel="stylesheet" type="text/css" href="
    /core/css/pagesmith/css-reset.css
    /core/css/pagesmith/two-col-lists.css
    /core/css/pagesmith/tables.css
    /core/css/pagesmith/links.css
    /core/css/pagesmith/references.css
    /core/css/ext/thickbox.css
    /core/css/templates/ps/images.css

    /core/css/pagesmith/collapse.css

    /core/css/templates/page-frame.css
    /core/css/templates/general.css
    /core/css/templates/width-960.css

    /core/css/templates/side/width-960.css
    /core/css/templates/side/nav-content.css

    /core/css/templates/references.css

    /core/css/developer/error-messages.css
    /core/css/developer/developer-panel.css

    /[[HtdocsSubDir]]/css/[[HtdocsSubDir]].css
  " />
<!--[if lt IE 9]>
  <link rel="stylesheet" type="text/css" href="
    /core/css/pagesmith/ieall.css
    /core/css/ext/thickbox-ieall.css
  " />
<![endif]-->
<!--[if lt IE 8]>
  <link rel="stylesheet" type="text/css" href="
    /core/css/pagesmith/ie.css
    /core/css/ext/thickbox-ie.css
  " />
<![endif]-->
</head>
<body>
  <div id="wrap">
    <div id="nav">
      <a href="/"><img src="/[[HtdocsSubDir]]/gfx/[[HtdocsSubDir]]_logo.png" alt="[[ShortDomainName]]" id="leftimg" /></a>
      <ul>
        <li><a href="/">Home</a></li>

        <li><a href="/contact.html">Contact us</a></li>
      </ul>
    </div>
    <div id="content">
      <% content %>
    </div>
    <div class="x">&nbsp;</div>
  </div>
  <p id="inst">
    <span id="tsandcs">
    <a href="/cookiespolicy.html">Cookies policy</a> | <a href="/legal.html">Terms &amp; Conditions.</a>
    </span>
    This site is hosted by the XXX
  </p>
  <%~ Developer_Messages -severity all -stack_trace 5 -stack_trace_level warn ~%>
  <script type="text/javascript" src="
    /core/js/pagesmith/core.js
    /core/js/ext/json2.js
    /core/js/ext/jquery.js
    /core/js/ext/jquery-migrate-1.2.1.js
    /core/js/ext/jquery.livequery.js
    /core/js/ext/jquery.metadata.js
    /core/js/ext/jquery.tablesorter.js
    /core/js/ext/jquery.tablesorter.pfe.js
    /core/js/ext/thickbox.js
    /core/js/pagesmith/table-sorter-loader.js
    /core/js/pagesmith/external-links.js
    /core/js/pagesmith/collapse.js

    /[[HtdocsSubDir]]/js/[[HtdocsSubDir]].js
  " ></script>

</body>
</html>
