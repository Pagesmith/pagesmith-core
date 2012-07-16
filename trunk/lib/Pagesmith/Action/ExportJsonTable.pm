package Pagesmith::Action::ExportJsonTable;

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

# Modules used by the code!

sub run {
  my $self = shift;
  my $format = lc $self->next_path_info;
  my $filter = $self->param('filter');
  if( $filter ) {
    $filter =~ s{\W+}{_}mxsg;
    $filter = "-filter_$filter";
  }
  my $summary = $self->param('summary');
  if( $summary ) {
    $summary =~ s{\W+}{_}mxsg;
    $summary = "-$summary";
  }

  $self->download_as( "export$summary$filter.$format" );

  return $self->json->print( $self->param( 'json' ) )->ok                   if $format eq 'json';

  ## Unpack json data into { 'head' => [ [] ], 'body' => [ [] ]

  my $table_data = $self->json_decode( $self->param( 'json' ) );

  ## Decode table data....
  return $self->csv_print(   $table_data->{'head'}, $table_data->{'body'} ) if $format eq 'csv';
  return $self->excel_print( $table_data->{'head'}, $table_data->{'body'} ) if $format eq 'xls';
  return $self->tsv_print(   $table_data->{'head'}, $table_data->{'body'} );
}

1;
