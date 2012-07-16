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

use base qw(Pagesmith::Component);

use Pagesmith::Adaptor;
use Pagesmith::HTML::Table;

sub ajax {
  #@return true if "-ajax" switch is in <% %> block
  my $self = shift;
  return $self->option( 'ajax' );
}

sub execute {
  my $self = shift;

  my $db = $self->next_par;
  my $dba = Pagesmith::Adaptor->new( $db );

  return sprintf '<h3>Database: %s</h3><p>Unable to connect</p>', encode_entities($db) unless $dba->dbh;

  my $tables = $dba->col( 'show tables' );
  ## no critic (Implicit Newline)
  my $html = sprintf '
  <h3>Database: %s</h3>
  <dl class="twocol">
    <dt>DSN:</dt><dd>%s</dd>
    <dt>User:</dt><dd>%s</dd>
  </dl>
  <div class="sub_nav">
    <h3>Tables</h3>
    <ul class="fake-tabs">
      <li><a href="#sub_%s_summary">Summary</a></li>
      %s
    </ul>
  </div>
  <div class="sub_data">
  <div id="sub_%s_summary" class="scrollable">
    <h3 class="keep">Tables</h3>
    %s
    ', $db, $dba->{'_dsn'}, $dba->{'_dbuser'}, $db,
    ( join q(), map { sprintf q(<li><a href="#sub_%s_%s">%s</a></li>), $db, $_, $_ } @{$tables} ),
    $db,
    $self->table_from_query( $dba, 'show table status' );
  ## use critic

  foreach my $tb ( @{$tables} ) {
    ## no critic (Implicit Newline)
    $html .= sprintf q(
    </div>
    <div id="sub_%s_%s" class="scrollable">
      <h3 class="keep">%s</h3>
      <h4>Columns</h4>
      %s
      <h4>Keys</h4>
      %s), $db, $tb, $tb,
      $self->table_from_query( $dba, "describe $tb" ),
      $self->table_from_query( $dba, "show keys from $tb" );
    ## use critic
  }

  $html .= qq(\n    </div>\n  </div>);
  return $html;
}

sub table_from_query {
  my( $self, $dba, $sql, @params ) = @_;
  my $sth = $dba->prepare( $sql );
  $sth->execute( @params );
  my $html = Pagesmith::HTML::Table->new(
    $self->r,
    {},
    [ map { {'key'=>$_} } @{ $sth->{'NAME'} } ],
    $sth->fetchall_arrayref( {} ),
  )->render;
  $sth->finish;
  return $html;
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
