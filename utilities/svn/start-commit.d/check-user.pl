#!/usr/bin/perl

## Sends an email on every commit!
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

use version qw(qv); our $VERSION = qv('0.1.0');

# The following libraries and block needed to get paths
# sorted out for lib to get the Pagesmith support modules
use Cwd qw(abs_path);
use English qw(-no_match_vars $PROGRAM_NAME $UID);
use File::Basename qw(dirname);

my $ROOT_PATH;
BEGIN { $ROOT_PATH = dirname(dirname(dirname(dirname(abs_path($PROGRAM_NAME))))); }
use lib "$ROOT_PATH/lib";

use Pagesmith::Utils::SVN::Support;
use Pagesmith::Utils::SVN::Config;

my $support = Pagesmith::Utils::SVN::Support->new;

## EXIT EARLY IF PARAMETERS INCORRECT!
exit $support->send_message( "Incorrect number of parameters\n" )->clean_up
  if @ARGV <= 1;

my( $repos, $user ) = @ARGV;

my($user_name) = getpwuid $UID;
(my $repos_name = $repos ) =~ s{\A.*/}{}mxs;

## Not configured correctly!
exit $support->send_message( "Repository '%s' checked out as user '%s' not '%s'\n", $repos, $user_name, $repos_name )->clean_up
  unless $repos_name eq $user_name;

my $config  = Pagesmith::Utils::SVN::Config->new( $ROOT_PATH );
exit 0 unless $config;
## We are not watching this repository - so we don't need to send anything
exit 0 unless $config->set_repos( $repos );
## User can commit to repository
exit 0 if     $config->set_user( $user );

exit $support->send_message( "User '%s' unable to commit to this repository '%s'\n", $user, $repos )->clean_up;

