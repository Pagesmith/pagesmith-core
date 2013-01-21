package Pagesmith::Component::Developer::ShowDbSchema;

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

use Data::Dumper qw(Dumper);
use HTML::Entities qw(encode_entities);
use Readonly qw(Readonly);

use base qw(Pagesmith::Component);

use Pagesmith::Adaptor;

Readonly my $DEFAULT_PAGE => 25;

sub usage {
  return {
    'parameters'  => q({db_key}),
    'description' => q(Display schema information from database - including keys),
    'notes' => [],
  };
}

sub define_options {
  my $self = shift;
  return (
    $self->ajax_option,
  );
}

sub ajax{
  my $self = shift;
  return $self->default_ajax;
}

sub my_table {
  my $self = shift;
  return $self->table
    ->make_sortable
    ->make_scrollable
    ->set_filter
    ->add_classes( 'before' )
    ->set_export( [qw(txt csv xls)] )
    ->set_pagination( [qw(10 25 50 all)], $DEFAULT_PAGE );
}

sub execute {
  my $self = shift;

  my $db = $self->next_par;
  my $dba = Pagesmith::Adaptor->new( $db );
  return $self->execute_mysql(  $db, $dba ) if $dba->is_type( 'mysql'  );
  return $self->execute_oracle( $db, $dba ) if $dba->is_type( 'oracle' );
  return '<h3>Unkown schema!</h3>';
}

sub execute_oracle {
  my( $self, $db, $dba ) = @_;
  return sprintf '<h3>Database: %s</h3><p>Unable to connect</p>', encode_entities($db) unless $dba->dbh;

  my $tables = $dba->hash( 'select TABLE_NAME, NUM_ROWS from USER_TABLES order by TABLE_NAME' );
  my $safe_map = {};
  foreach (sort keys %{$tables}) {
    (my $safe_name = $_) =~ s{\W}{_}mxsg;
    $safe_map->{$_} = $safe_name;
  }

  my $tabs = $self->tabs( { 'fake' => 1 } );
  $tabs->add_tab( "sub_${db}_summary", 'Summary',
    $self->my_table_from_query( $dba,
      'select TABLE_NAME, TABLESPACE_NAME, NUM_ROWS, AVG_ROW_LEN from USER_TABLES order by TABLE_NAME' ),
  );
  foreach my $tb ( sort keys %{$tables} ) {
    $tabs->add_tab(
      "sub_${db}_$safe_map->{$tb}",
      $tb.' ('.(defined $tables->{$tb} ? $tables->{$tb} : q(-)).')',
      sprintf '<h4>Columns</h4>%s<h4>Keys</h4>%s<h4>Samples</h4>%s',
        $self->my_table_from_query( $dba,
          'select COLUMN_NAME, DATA_TYPE, DATA_TYPE_MOD, DATA_LENGTH, NULLABLE, NUM_DISTINCT, NUM_NULLS from USER_TAB_COLUMNS where TABLE_NAME = ?',
          $tb ),
        $self->my_table_from_query( $dba,
          'SELECT A.CONSTRAINT_NAME, COLUMN_NAME, CONSTRAINT_TYPE, POSITION, INDEX_NAME, R_CONSTRAINT_NAME FROM ALL_CONS_COLUMNS A JOIN ALL_CONSTRAINTS C  ON A.CONSTRAINT_NAME = C.CONSTRAINT_NAME WHERE C.TABLE_NAME = ?',
          $tb ),
        $self->my_table_from_query( $dba,
          "select * from $tb WHERE ROWNUM<=20" ),
    );
  }
  ## no critic (Implicit Newline)
  return sprintf '
  <h3>Database: %s</h3>
  <dl class="twocol">
    <dt>DSN:</dt><dd>%s</dd>
    <dt>User:</dt><dd>%s</dd>
  </dl>
  <div class="sub_nav">
    <h3>Tables</h3>
    <div class="scrollable" style="height:300px">
      %s
    </div>
  </div>
  <div class="sub_data scrollable">
    %s
  </div>
    ', $db, $dba->{'_dsn'}, $dba->{'_dbuser'},
    $tabs->render_ul_block,
    $tabs->render_div_block;
  ## use critic
}

sub execute_mysql {
  my( $self, $db, $dba ) = @_;
  return sprintf '<h3>Database: %s</h3><p>Unable to connect</p>', encode_entities($db) unless $dba->dbh;

  my $tables = $dba->col( 'show tables' );
  ## no critic (Implicit Newline)
  my $tabs = $self->tabs( { 'fake' => 1 } );
  $tabs->add_tab( "sub_${db}_summary", 'Summary', $self->table_from_query( $dba, 'show table status' ) );
  foreach my $tb ( @{$tables} ) {
    $tabs->add_tab( "sub_${db}_$tb", $tb, sprintf '<h4>Columns</h4>%s<h4>Keys</h4>%s<h4>Samples</h4>%s',
      $self->my_table_from_query( $dba, "describe $tb" ),
      $self->my_table_from_query( $dba, "show keys from $tb" ),
      $self->my_table_from_query( $dba, "select * from $tb limit 20" ),
    );
  }

  ## no critic (Implicit Newline)
  return sprintf '
  <h3>Database: %s</h3>
  <dl class="twocol">
    <dt>DSN:</dt><dd>%s</dd>
    <dt>User:</dt><dd>%s</dd>
  </dl>
  <div class="sub_nav">
    <h3>Tables</h3>
    <div class="scrollable" style="height:300px">
      %s
    </div>
  </div>
  <div class="sub_data scrollable">
    %s
  </div>
    ', $db, $dba->{'_dsn'}, $dba->{'_dbuser'},
    $tabs->render_ul_block,
    $tabs->render_div_block;
  ## use critic
}

1;

__END__

h3. Syntax

<% Developer_ShowDbSchema
   database_key
%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes
