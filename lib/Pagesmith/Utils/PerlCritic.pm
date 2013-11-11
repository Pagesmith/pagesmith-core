package Pagesmith::Utils::PerlCritic;

## Exports list of critic rules to ignore!
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

use base qw(Exporter);

our @EXPORT_OK = qw(skip);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

sub skip {
#@ return hashref - keyed by rules to ignore
## Returns a hashref of rules - if value is true rule is ignored
  return {qw(
    ControlStructures::ProhibitUnlessBlocks        1
    ControlStructures::ProhibitPostfixControls     1
    CodeLayout::RequireTidyCode                    1
    ValuesAndExpressions::ProhibitImplicitNewlines 1
  )};
}

1;

__END__
Notes
-----

These are all places where Conway gets it wrong, although good to report them:

 * __UnlessBlocks__ - much easier to read conditional if haven't got to invert values
 * __PostfixControls__ - Too useful to simplify code
 * __TidyCode__ - No perl tidy option to correctly handle function brackets in all cases
 * __ImplicitNewlines__ - Here docs are not handled well by editors & concatenation is inefficient and makes code logic hard to follow
