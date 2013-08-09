package Pagesmith::Action::ExportTable;

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
  my $comp_obj;
  my $status = eval { $comp_obj = $module->new($self); };  ## Not sure if I like this here!!
  if( $EVAL_ERROR ) {
    $self->push_message(  "$component failed to instantiate: module $module:\n" . $EVAL_ERROR, 'fatal' );
    return $self->server_error;
  }

  ## Get the component object, and then call the configure function!
  my $table           = $comp_obj->data_table;
  my $adaptor         = $comp_obj->data_adaptor;
  return $self->not_found unless $table && $adaptor;

  my $iterator_method = $comp_obj->iterator_method;

  my $iterator        = $adaptor->$iterator_method(
    $table->parse_structure( $self->json_decode( $self->trim_param( 'config' )||q({}) ) ),
  );

  my @colkeys = map { $_->{'key'}   } my @columns = $table->columns;

# Specify its CSV, give it's filename AND then write out the header column!

  $self->csv
       ->download_as( $comp_obj->export_filename )
       ->say( $self->csv_line( map { $_->{'label'} } @columns ) );            # Heading line

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
