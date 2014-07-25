package Pagesmith::Action::Developer::Tableexample;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2014 Genome Research Ltd.
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

## Handles external links (e.g. publmed links)
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

use base qw(Pagesmith::Action::Ensembl);

use Pagesmith::HTML::Table;

sub run {
  my $self   = shift;

## no critic (LongChainsOfMethodCalls InterpolationOfMetachars) - the API is designed to be chained (most methods return self!)!
  return $self->html->print(
    Pagesmith::HTML::Table->new()
      ->make_sortable
      ->set_summary( 'Email and telephone number list' )
      ->set_option( 'title', 'TEST' )
      ->set_option( 'id', 'this_is_a_test' )
      ->add_classes( qw(a b c d e) )
      ->add_columns(
        { 'key' => q(#) },
        { 'key' => 'id', 'label' => 'ID',    'align' => 'right', 'template' => '<a href="details/[[u:id]]">[[h:id]]</a>', },
        { 'key' => 'nm', 'label' => 'Name',  },
        { 'key' => 'em', 'label' => 'Email', 'format' => 'email', },
        { 'key' => q(),   'label' => 'Full',  'template' => '[[h:nm]] ([[email:em]])', },
        { 'key' => 'ph', 'label' => 'Phone', 'align' => 'center', },
        { 'key' => 'dt', 'label' => 'Date',  'format' => 'datetime' },
      )
      ->add_data(
        { 'id' => 'fb1', 'nm' => 'Fred Smith', 'em' => 'fred.smith@mydomain.com', 'ph' => '1234', 'dt' => '2010-01-01 12:33:55' },
        { 'id' => 'jb3', 'nm' => 'John Brown',  'em' => 'jb3@mydomain.com',         'ph' => '9876', 'dt' => '2010-01-01 12:33:55' },
      )
      ->add_data(
        { 'id' => 'jd9', 'nm' => 'John Doe',        'em' => 'jd9@mydomain.com',         'ph' => '1919', 'dt' => '2010-01-01 12:33:55' },
      )
      ->add_block( 'foot' )
      ->add_data(
        { 'id' => 'Total', 'nm' => '3' },
      )
      ->render )->ok;
## use critic
}

1;
