package Pagesmith::Utils::PerlCritic;

##g
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

use base qw(Exporter);

our @EXPORT_OK = qw(skip);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

sub skip {
  return {qw(
    ControlStructures::ProhibitUnlessBlocks        1
    ControlStructures::ProhibitPostfixControls     1
    CodeLayout::RequireTidyCode                    1
    ValuesAndExpressions::ProhibitImplicitNewlines 0
  )};
}
1;
