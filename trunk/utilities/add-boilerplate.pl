#!/usr/bin/perl

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

## Check to see if appropriate boilerplate is present
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
use version qw(qv); our $VERSION = qv('1.0.0');

use English qw(-no_match_vars $PROGRAM_NAME);
use File::Basename qw(dirname basename);
use Cwd qw(abs_path);
use List::MoreUtils qw(any);
use Text::Wrap qw($columns wrap);
    $columns = 72; ## no critic (MagicNumbers)

my $ROOT_PATH;
BEGIN { $ROOT_PATH = dirname(dirname(abs_path($PROGRAM_NAME))); }
use lib "$ROOT_PATH/lib";

use Pagesmith::Root;

my $year = (gmtime)[5] + 1900; ## no critic (MagicNumbers)
my %name_map = (
  'pagesmith-core' => 'the Pagesmith web framework',
  'sanger-core'    => 'the WTSI extensions to Pagesmith web framework',
  'oa2'            => 'the OAuth2 extensions to Pagesmith web framework',
  'user-accounts'  => 'the User account management extensions to Pagesmith web framework',
  'web-utilties'   => 'the Pagesmith support and management utilities suite',
);

## no critic (BriefOpen RequireChecked)
my $runobj = Pagesmith::Root->new;

foreach my $fn (@ARGV) {
  open my $fh, q(+<), $fn;
  unless( $fh ) {
    warn "Unable to parse file $fn\n";
    next;
  }
  my @lines = <$fh>;
  seek $fh,0,0;
  if( any { m{\A[#][|][ ]Copyright[ ][(]c[)][ ]}mxs } @lines ) {
    warn "Already has copyright block file $fn\n";
    next;
  }
  my $out = $runobj->run_cmd( ['svn', 'log', $fn] );
  my %Y;
  foreach( @{$out->{'stdout'}||[]} ) {
    if( m{\Ar\d+[ ][|][ ][-\w]+[ ][|][ ](\d{4})-\d\d-\d\d[ ]}mxs ) {
      $Y{$1}++;
    }
  }
  $Y{$year} = 1;

  ## Get repository name!;
  $out = $runobj->run_cmd( ['svn', 'info', $fn] );
  my @out = grep { m{\ARepository[ ]Root:}mxs } @{$out->{'stdout'}||[]};
  my @full_path = split m{/}mxs, abs_path( $fn );
  pop @full_path;
  while( @full_path ) {
    last if @out;
    my $pn = join q(/), @full_path;
    $out = $runobj->run_cmd( ['svn', 'info', $pn] );
    @out = grep { m{\ARepository[ ]Root:}mxs } @{$out->{'stdout'}||[]};
    pop @full_path;
  }

  my $name = q();
  ($name) = $out[0] =~ m{([-.\w+]+)\Z}mxs if @out;

  $name = exists $name_map{$name}
        ? $name_map{$name}
        : ("the Pagesmith managed website $name" =~ s{-}{.}mxsgr);

  my $header_text = wrap( q(#| ), q(#| ), 'This file is part of '.$name.q(.) );
  my $msg_text    = wrap( q(#| ), q(#| ), ucfirst $name.' is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later version.' );

  ## no critic (InterpolationOfMetachars)
  my $boiler_plate = sprintf '
#+----------------------------------------------------------------------
#| Copyright (c) %3$s Genome Research Ltd.
%1$s
#+----------------------------------------------------------------------
%2$s
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

',
    $header_text, $msg_text, join q(, ), sort keys %Y;
  splice @lines,1,1,$boiler_plate;

  truncate $fh,0;
  print {$fh} @lines;
  close $fh;
  warn "## File $fn patched\n";
}

## use critic
