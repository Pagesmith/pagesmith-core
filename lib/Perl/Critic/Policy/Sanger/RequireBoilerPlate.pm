package Perl::Critic::Policy::Sanger::RequireBoilerPlate;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
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

## Policy to require Sanger boilerplate as above to be included in
## all perl files..
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
use version qw(qv); our $VERSION = qv('1.0.1');

use Perl::Critic::Utils qw($SEVERITY_HIGH);
use base 'Perl::Critic::Policy';
use Const::Fast qw(const);


sub default_severity {
  return $SEVERITY_HIGH;
}

sub default_themes {
  return qw( sanger cosmetic );
}

sub applies_to {
  return 'PPI::Document';
}

sub supported_paramters {
  return q();
}

sub violates {
  my( $self, $elem, $doc ) = @_;

## no critic (ImplicitNewlines)
my $expl = q(Your file must include the standard sanger copyright
notice boilerplate at the start of the file:

Which includes the following text:

  "Copyright (c) {years}+ Genome Research Ltd"

and

  "GNU Lesser General Public License"

To add boilerplate to you perl modules/utilities run:

 * utilities/add-boilerplate.pl {perl-file-name}+

This will automatically add copyright notice (incl
svn log years) and lgpl license statement to the file.

);
## use critic

  my $comm = $self->_find_wanted_nodes( $doc );
  $comm =~ s{\s+}{ }mxsg;
  my @viols;
  push @viols, $self->violation( 'Missing/incorrect copyright notice', $expl, $doc )
    unless $comm =~ m{Copyright[ ][(]c[)][ ](?:\d{4}(?:-\d{4})?,[ ]?)*\d{4}(?:-\d{4})?[ ]Genome[ ]Research[ ]Ltd[.]}mxs; ## no critic (ComplexRegexes)
  push @viols, $self->violation( 'Missing/incorrect license notice.', $expl, $doc )
    unless $comm =~ m{GNU[ ]Lesser[ ]General[ ]Public[ ]License}mxs;
  return @viols;
}

sub _find_wanted_nodes {
  my( $self, $doc ) = @_;
  return join q( ), map { m{\A[#][|]\s+(.*)}mxs ? $1 : () } @{$doc->find('PPI::Token::Comment')||[]};
}

## use critic;

1;
