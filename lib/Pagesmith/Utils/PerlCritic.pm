package Pagesmith::Utils::PerlCritic;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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
