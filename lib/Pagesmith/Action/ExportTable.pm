package Pagesmith::Action::ExportTable;

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

## Dumps raw HTML of the file to the browser (syntax highlighted)
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
use feature ':5.10';

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action);
use English qw(-no_match_vars $EVAL_ERROR);
use Pagesmith::ConfigHash qw(can_name_space);
use List::MoreUtils qw(any);

# Modules used by the code!

sub run {
  my $self = shift;

## Part 1 - dynamically include the component we are trying to export the SQL from!

  my $component = $self->safe_module_name( $self->next_path_info );
  if( $component =~ m{\A([[:alnum:]]+)::}mxs && ! can_name_space( $1 ) ) {
    warn "ACTION: cannot perform $component - not in valid name space\n";
    return $self->forbidden;
  }
  my $module = 'Pagesmith::Component::'.$component;
  unless ( $self->dynamic_use($module) ) {
    ( my $module_tweaked = $module ) =~ s{::}{/}mxgs;
    if( $self->dynamic_use_failure($module) =~ m{\ACan't\slocate\s$module_tweaked[.]pm\sin\s@INC}mxs ) {
      $self->push_message( "Unknown Component $component", 'fatal' );
      return $self->not_found;
    }
    $self->push_message( "$component failed to compile: module $module:\n" . $self->dynamic_use_failure($module    ), 'fatal' );
    return $self->server_error;
  }

## Get the component object!

  my $comp_obj;
  my $status = eval { $comp_obj = $module->new($self); };  ## Not sure if I like this here!!
  if( $EVAL_ERROR ) {
    $self->push_message(  "$component failed to instantiate: module $module:\n" . $EVAL_ERROR, 'fatal' );
    return $self->server_error;
  }

## Get table, adapor, and SQL structure from object!

  my $table           = $comp_obj->data_table;
  my $adaptor         = $comp_obj->data_adaptor;
  return $self->not_found unless $table && $adaptor;

  my $results_sql     = $comp_obj->data_sql(
    $table->parse_structure( $self->json_decode( $self->trim_param( 'config' )||q({}) ) ) );

# Specify its CSV, give it's filename AND then write out the header column!

  my @columns = $table->columns;

  $self->csv
       ->download_as( $comp_obj->export_filename )
       ->say( $self->csv_line( map { $_->{'label'} } @columns ) );            # Heading line

  return $self->ok unless $results_sql;

## Short cut output if we have no iterator.. happens when SQL is know to return no entries!!

  my $iterator  = $adaptor->get_iterator( $results_sql->{'sql'}, @{$results_sql->{'pars'}} );
  my @colkeys   = map { $_->{'key'} } @columns;

# We now treat the code in one of two ways - to see if we have any columns which need to
# be munged before being output!

  if( any { exists $_->{'code_ref'} } @columns ) {
    my %cols_with_code_refs;
    my $c           = 0;
    foreach( @columns ) { ## Look for elements we wish to re-map using table code ref!
      $cols_with_code_refs{$c} = $_->{'code_ref'} if exists $_->{'code_ref'};
      $c++;
    }
    while( my $row = $iterator->get ) {
      my @row_data  = @{$row}{@colkeys};
      $row_data[$_] = &{$cols_with_code_refs{$_}}($row) foreach keys %cols_with_code_refs;
      $self->say( $self->csv_line( @row_data ) );
    }
  } else { ## This is likely to be the usual case so we are going to handle it slightly more efficiently
    $self->say( $self->csv_line( @{$_}{@colkeys} ) ) while $_ = $iterator->get;
  }

# Finally return that the script has run successfully

  return $self->ok;
}

1;
