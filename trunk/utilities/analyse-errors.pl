#!/usr/bin/perl

## Move stuff from trunk to stage....
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

use HTML::Entities qw(encode_entities);

use English qw(-no_match_vars $PROGRAM_NAME $EVAL_ERROR);
use File::Basename qw(dirname basename);
use Cwd qw(abs_path);
use Carp qw(croak);
use Const::Fast qw(const);
use Getopt::Long qw(GetOptions);

# Define constants and data-structures

my $ROOT_PATH;
BEGIN { $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME))); }
use lib "$ROOT_PATH/lib";


use Pagesmith::Root;

my $s = Pagesmith::Root->new;

my $lr = $ROOT_PATH.'/logs';
## If it is www-.... then look for
$lr = "/www/tmp/$1/logs" if $ROOT_PATH =~ m{^\/www\/((\w+\/)?www-\w+)}mxs;
my $el = "$lr/error.log";

my $command_warn  = ['grep', 'warn]',  $el];
my $command_error = ['grep', 'error]', $el];

my $res = $s->run_cmd( $command_warn );

if( $res->{'success'} ) {
  my %counts;
  $counts{ $_ } ++ foreach @{$res->{'stdout'}};
  printf "%s\n-----------------------------------\n  %s\n\n", "@{$command_warn}",
    join "\n  ",
    map  { sprintf "%7d\t%s", @{$_} }
    sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] }
    map  { [ $counts{$_}, $_ ] }
    keys %counts;
}

$res = $s->run_cmd( $command_error );
if( $res->{'success'} ) {
  my %counts;
  foreach (@{$res->{'stdout'}}) {
    s{\A\[\w{3}[ ]\w{3}.*?]\s*}{}mxs;
    s{\[client[ ].*?\]\s*}{}mxs;
    s{\s+\Z}{}mxs;
    s{\A\s+}{}mxs;
    s{\s+}{ }mxsg;
    $counts{$_}++;
  }
  printf "%s\n-----------------------------------\n  %s\n\n", "@{$command_error}",
    join "\n  ",
    map  { sprintf "%7d\t%s", @{$_} }
    sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] }
    map  { [ $counts{$_}, $_ ] }
    keys %counts;
}

