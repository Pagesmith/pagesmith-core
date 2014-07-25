package Pagesmith::Utils::PerlHighlighter;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

## Wrapper around Syntax::Highlight::Perl::Improved
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

use Syntax::Highlight::Perl::Improved;

my %ct = (
  'Variable_Scalar'   => 'p-sc', #080
  'Variable_Array'    => 'p-ar', #f70
  'Variable_Hash'     => 'p-hs', #80f
  'Variable_Typeglob' => 'p-tg', #f03
  'Subroutine'        => 'p-sb', #980
  'Quote'             => 'p-qu', #00a background-color:white
  'String'            => 'p-st', #00a background-color:white
  'Bareword'          => 'p-bw', #f00 font-weight: bold
  'Package'           => 'p-pa', #900
  'Number'            => 'p-nu', #f0f
  'Operator'          => 'p-op', #900 font-weight:bold
  'Symbol'            => 'p-sy', #000
  'Keyword'           => 'p-kw', #000
  'Builtin_Operator'  => 'p-bo', #300
  'Builtin_Function'  => 'p-bf', #001
  'Character'         => 'p-ch', #800
  'Directive'         => 'p-di', #399
  'Label'             => 'p-la', #939
  'Line'              => 'p-li', #000
  'Comment_Normal'    => 'p-cn', #069 background-color:#ffc
  'Comment_POD'       => 'p-cp', #069 background-color:#ffc
);

my $self;

sub new {
  my $class = shift;
  return $self if $self;
  my $self = Syntax::Highlight::Perl::Improved->new;
     $self->define_substitution(qw(< &lt; > &gt; & &amp;)); # HTML escapes.
  # install the formats set up above
     $self->set_format( $_, [qq(<span class="$ct{$_}">), '</span>'] ) foreach keys %ct;
  return $self;
}

1;