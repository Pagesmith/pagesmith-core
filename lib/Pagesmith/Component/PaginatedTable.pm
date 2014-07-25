package Pagesmith::Component::PaginatedTable;

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

## Table generating component for opsview!
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

use Time::HiRes qw(time);
use Date::Format qw(time2str);

use base qw(Pagesmith::Component);

my $user_name_cache = {};

sub data_sql {
  my( $self, $params ) = @_;
  return $self->data_adaptor->get_results_sql( $params );
}

sub data_table {             ## Must override
  my $self = shift;
  return;
}

sub data_adaptor {           ## Must override
  my $self = shift;
  return;
}

sub export_prefix {
  my $self = shift;
  return 'export';
}

sub export_filename {
  my $self = shift;
  return $self->export_prefix.time2str( '-%Y-%m-%d--%H-%M.csv', time );
}

sub usage {
  return (
    'parameters'  => q(json structure representing sort/filter options...),
    'description' => q(Generate table...),
    'notes' => [],
  );
}

sub define_options {
  my $self = shift;
  return ( $self->ajax_option );
}

sub ajax {
  my $self = shift;
  return $self->default_ajax;
}

sub parsed_options {
  return q();
}

sub execute {
  my $self = shift;

  my $structure    = $self->json_decode( join q( ),$self->pars )||{};
  my $table        = $self->data_table;

  return '<p>You must overrid get_comp_table</p>' unless $table;

  my ($count,$results) = $self->data_adaptor->count_and_hash(
    $self->data_sql( $table->parse_structure( $structure ) ) );

  (my $module_name = ref $self) =~ s{^Pagesmith::Component::}{}mxs;
  ## no critic (LongChainsOfMethodCalls)
  $table->set_count( $count )
        ->set_refresh_url( '/component/'.$module_name )
        ->set_refresh_opts( $self->parsed_options )
        ->set_export_url(  '/action/ExportTable/'.$module_name )
        ->add_data( @{$results} ); ## Attach count and data!
  ## use critic
  ## If structure page is set it is the ajax request to refresh the table body - so we just return the first block (and count!)
  return exists $structure->{'page'} ? $table->render_first_block : $table->render;
}

1;
