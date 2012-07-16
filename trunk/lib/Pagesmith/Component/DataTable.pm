package Pagesmith::Component::DataTable;

## Page to render results of an SQL query...
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

use Readonly qw(Readonly);
Readonly my $PAGINATE_SIZE => 3;

use base qw(Pagesmith::Component);

use DBI;
use HTML::Entities qw(encode_entities);
use POSIX qw(ceil);

use Pagesmith::Cache;
use Pagesmith::Core qw(safe_md5);

sub _cache_key {
## Do not cache!
  return;
}

sub cache_expiry {
## Do not cache!
  return;
}

##no critic (ExcessComplexity)
sub execute {
## Main function
  my $self = shift;

  my ( $query, @pars ) = $self->pars;
  ## Syntax is <% DataTable [options] "query" "par1" "par2" ... %>
  my $par = $self->option('parameter') || 'block';    ## Paging parameter
  my @real_pars;
  ## Loop through parameters and if any start with a "$" grab the
  ## appropriate APR parameter.
  foreach (@pars) {
    if (m{\A\$(\w+)\s*(.*)\Z}mxs) {
      my ($t) = $self->page->apr->param($1);
      $t = $2 unless defined $t;
      push @real_pars, $t;
    } else {
      push @real_pars, $_;
    }
  }

  my $table_data;    ## An two element hash containing an array of column names and a 2d array of data
  my $rows;            ## No of rows returned by the query
  my( $sth, $err, $err_extra );
  if ( $self->option('cache_expiry') ) {
    ## We will cache the query to memory/SQL/Disc
    ## Generate a cache handle to try and retrieve data!
    my $ch = Pagesmith::Cache->new( 'tmpdata', safe_md5($query) . q(--) . safe_md5( join "\n\n\n\n", @real_pars ) );
    $table_data = $ch->get;
    unless ($table_data) {
      ( $sth, $err, $err_extra ) = $self->_generate_sth( $query, @real_pars );    ## Connect to database and try to execute query.
      unless ( defined $sth ) {
        $self->page->push_message( "$err\n$err_extra", 'error', 1 );
        return $self->_error($err);
      }
      $table_data = {
        'head' => [@{ $sth->{'NAME'} }],                                           ## Column names to use as captions
        'data' => $sth->fetchall_arrayref(),                                      ## Data
      };
      $ch->set( $table_data, -$self->option('cache_expiry') );                         ## Store the resulting SQL in the cache
    }
    $rows = @{ $table_data->{'data'} };
  } else {
    ## This is the non cached version so we try and do the same thing!
    ( $sth, $err, $err_extra ) = $self->_generate_sth( $query, @real_pars );         ## Connect to database and try to execute query.
    unless ( defined $sth ) {
      $self->page->push_message( "$err\n$err_extra", 'error', 1 );
      return $self->_error($err);
    }
    $rows = $sth->rows;
  }
  ## We have no data so generate an "information message"
  return sprintf '<p>%s</p>', encode_entities( $self->option('empty') || 'Your query returned no data' ) unless $rows;

  my $include_index = $self->option('include_index');    ## Do we include an incrementing index down the LHS of the page

  ( my $pagesize = $self->option('pagesize') ) =~ s{\D}{}mxgs;    ## Get the page size if set... if set causes pagination!
  $pagesize = 0 if $pagesize < 0;

  my $rows_to_display = $rows;
  my $page            = 0;
  my $max_page        = 0;
  if ($pagesize) {    ## We are paginating..... so check the page we are on is within the range!
    $page     = $self->page->apr->param($par);
    $max_page = ceil( $rows / $pagesize ) - 1;
    $page     = 0 unless $page;
    $page     = 0 if $page < 0;
    $page     = $max_page if $page > $max_page;
    if ( $page && !$table_data ) {    ## Skip and discard the initial rows!
      $sth->fetchrow_array() foreach 1 .. ( $page * $pagesize );
    }
    $rows_to_display = $pagesize;
  }

  ## This is a hack at the moment - find a better table class - and look at
  ## table sort SQL to remove the need for an "id"
  my $return = sprintf '<table class="%s" style="width:90%%;margin:0 auto" summary="%s">',
    $self->option('sortable') ? 'sorted-table' : 'zebra-table',
    $self->option('summary')  ? encode_entities( $self->option('summary') ) : 'Table of data'
    ;
  my @classes = split m{,}mxs, $self->option('align');
  ## Show the header row (if not turned off)
  if ( $self->option('header_row') ne 'off' ) {
    $return .= "\n<thead>\n<tr>";
    $return .= '<th class="header">#</th>' if $include_index;
    foreach ( @{ $table_data ? $table_data->{'head'} : $sth->{'NAME'} } ) {
      $return .= sprintf '<th class="header">%s</th>', encode_entities($_);
    }
    $return .= "</tr>\n</thead>";
  }

  ## Show the main body of the table
  $return .= '<tbody>';
  my $row_id = $page * $pagesize;
  while ( $row_id < $rows ) {
    my $arr = $table_data ? $table_data->{'data'}[$row_id] : $sth->fetchrow_arrayref;
    $return .= "\n<tr>";
    my $o = 0;
    $return .= sprintf '<td>%d</td>', ++$row_id if $include_index;
    foreach (@{$arr}) {
      $return .= sprintf '<td class="%s">%s</td>', $classes[$o] || 'c', encode_entities($_);
      $o++;
    }
    $return .= '</tr>';
    $rows_to_display--;
    last unless $rows_to_display;
  }
  $return .= "\n</tbody></table>";

  $sth->finish if $sth;    ## If we have a valid statement then destroy it!

  ## If we are paginating add a pagination block!
  if ( $pagesize && $max_page ) {
    $self->page->apr->delete($par);    ## Remove the current page parameter
    $return .= $self->_paginate( {
      'url'       => $self->r->uri,
      'qs'        => $self->_qs,
      'page'      => $page,
      'parameter' => $par,
      'pagesize'  => $pagesize,
      'entries'   => $pagesize - $rows_to_display,
      'max_page'  => $max_page,
      'rows'      => $rows,
    } );
  }
  return $return;
}
##use critic (ExcessComplexity)

sub _generate_sth {
## Generate an DBI StatementHandle object
## return statement handle if successful OR (undef & error message) if failed.
  my( $self,$query,@params ) = @_;
  my $dbh   = DBI->connect( 'dbi:' . $self->option('dsn'), q() . $self->option('user'), q() . $self->option('pass') );
  return ( undef, 'Unable to connect to database', $DBI::errstr ) unless $dbh; ##no critic (PackageVars)
  my $sth = $dbh->prepare($query);
  unless ($sth) {
    return ( undef, 'Unable to prepare query', $DBI::err ); ##no critic (PackageVars)
  }
  unless ( $sth->execute(@params) ) {
    my %x = %{ $sth->{'ParamValues'} || {} };
    ##no critic (PackageVars)
    my $x = $DBI::errstr
          . "\nDatabase: $dbh->{Name}\n$sth->{Statement}\nParameters:\n"
          . join "\n", map { "        $x{$_}" } sort keys %x;
    ##use critic (PackageVars)
    $sth->finish;
    return ( undef, 'Unable to execute query', $x );
  }
  ## We have a valid SQL statement handle that has been executed
  return ($sth);
}

sub _paginate {
## Generate a series of links to navigate from one page within the table to
## the next: as follows....
##
##     << < 1 2 3 ..... m-2 m-1 [m] m+1 m+2 ..... n-2 n-1 n > >>
##
  my ( $self, $pars ) = @_;
  my $url =
    $pars->{'qs'}
    ? "$pars->{'url'}?$pars->{'qs'};$pars->{'parameter'}="
    : "$pars->{'url'}?$pars->{'parameter'}=";
  ## Include details of the entries being shown....
  my $html = sprintf qq(\n<p class="paginate">%d - %d of %d - ),
    $pars->{'page'} * $pars->{'pagesize'} + 1,
    $pars->{'page'} * $pars->{'pagesize'} + $pars->{'entries'},
    $pars->{'rows'};
  ## If we aren't on the first page show a "<<" and "<" link
  if ( $pars->{'page'} ) {
    $html .= sprintf ' <a href="%s">&#171;</a>', $url, 0;
    $html .= sprintf ' <a href="%s%d">&lt;</a>', $url, $pars->{'page'} - 1;
  }
  ## Show all the numeric links
  foreach my $i ( 0..($pars->{'max_page'}) ) {
    if ( ( $i < $PAGINATE_SIZE )
      || ( abs $i - $pars->{'page'} < $PAGINATE_SIZE )
      || ( $pars->{'max_page'} - $i < $PAGINATE_SIZE ) ) {
      $html .=
        ( $i == $pars->{'page'} )
        ? sprintf ' <strong>%d</strong>', $i + 1
        : sprintf ' <a href="%s%d">%d</a>', $url, $i, $i + 1;
    } else {
      $html .= ' ...';
      $i = $i < $pars->{'page'}
        ? $pars->{'page'} - $PAGINATE_SIZE        ## Skip entries between 3 and m-3
        : $pars->{'max_page'} - $PAGINATE_SIZE    ## Skip entries between m+3 and n-3
        ;
    }
  }
  ## Now we add ">" and ">>" links if we aren't on the last page!
  if ( $pars->{'page'} < $pars->{'max_page'} ) {
    $html .= sprintf ' <a href="%s%d">&gt;</a>',   $url, $pars->{'page'};
    $html .= sprintf ' <a href="%s%d">&#187;</a>', $url, $pars->{'max_page'};
  }

  $html .= '</p>';
  return $html;
}

1;

__END__

h3. Currently under redevelopment

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

