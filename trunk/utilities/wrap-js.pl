#!/usr/bin/perl

## Wrap a js file in jshint ignore:start/end

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

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);

foreach my $fn (@ARGV) {
  if( open my $fh, q(<), $fn ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $contents = <$fh>;
    close $fh; ## no critic (RequireChecked)
    next if $contents =~ m{\A/[*][ ]jshint[ ]ignore:start[ ][*]/}mxs;
    if( open $fh, q(>), $fn ) {
      printf {$fh} "/* jshint ignore:start */\n%s\n/* jshint ignore:end */\n", $contents;
      close $fh; ## no critic (RequireChecked)
    }
  }
}
