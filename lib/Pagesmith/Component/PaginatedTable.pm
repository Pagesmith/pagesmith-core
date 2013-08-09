package Pagesmith::Component::PaginatedTable;

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

sub iterator_method {
  my $self = shift;
  return 'get_results_iterator';
}

sub results_method {
  my $self = shift;
  return 'get_results';
}

sub data_table {     ## Must override
  my $self = shift;
  return;
}

sub data_adaptor {   ## Must override
  my $self = shift;
  return;
}

sub export_prefix {
  my $self = shift;
  return 'export';
}

sub export_filename {
  my $self = shift;
  return $self->export_prefix.time2str( '-%Y-%m-%d--%H-%m.csv', time );
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

sub execute {
  my $self = shift;

  my $structure    = $self->json_decode( join q( ),$self->pars )||{};
  my $table        = $self->data_table;
  return '<p>You must overrider get_comp_table</p>' unless $table;
  my $fetch_method = $self->results_method;
  my ($count,$results) = $self->data_adaptor->$fetch_method(
    $table->parse_structure( $structure ) );

  (my $module_name = ref $self) =~ s{^Pagesmith::Component::}{}mxs;
  ## no critic (LongChainsOfMethodCalls)
  $table->set_count( $count )
        ->set_refresh_url( '/component/'.$module_name )
        ->set_export_url(  '/action/ExportTable/'.$module_name )
        ->add_data( @{$results} ); ## Attach count and data!
  ## use critic
  ## If structure page is set it is the ajax request to refresh the table body - so we just return the first block (and count!)
  return exists $structure->{'page'} ? $table->render_first_block : $table->render;
}

1;
