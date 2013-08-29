#!/usr/bin/perl

## Generate a random 8 character code 39 barcode!
##
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

use English qw(-no_match_vars $PROGRAM_NAME);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $ROOT_PATH;
BEGIN { $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME))); }
use lib "$ROOT_PATH/lib";

use Pagesmith::Utils::Code39;

my $c39obj = Pagesmith::Utils::Code39->new;

my $csum = $c39obj->checksum( my $bc = join q(), map { $c39obj->random_symbol } qw(. . . . . . .) );

printf "%s%s\n", $bc,$csum;
