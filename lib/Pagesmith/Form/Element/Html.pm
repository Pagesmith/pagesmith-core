package Pagesmith::Form::Element::Html;

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

use Const::Fast qw(const);
const my $DEFAULT_ROWS => 20;
const my $DEFAULT_COLS => 80;

use base qw( Pagesmith::Form::Element::Text );

use Pagesmith::Utils::Validator::XHTML;

### Html fragment text area element - will need to map JavaScript validator back into Perl to make
### sure that the validation does not allow HTML check to be bypassed
### This package checks for a limited safe subset of HTML tags

sub init {
  my( $self, $params ) = @_;
  $self->{'_rows'} = $params->{'rows'} || $DEFAULT_ROWS;
  $self->{'_cols'} = $params->{'cols'} || $DEFAULT_COLS;
  return;
}

sub validate {
  my $self = shift;
  my $validator = Pagesmith::Utils::Validator::XHTML->new;
  return $self->set_invalid if $validator->validate( $self->value );
  return $self->set_valid;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_html' );
  return;
}


1;
