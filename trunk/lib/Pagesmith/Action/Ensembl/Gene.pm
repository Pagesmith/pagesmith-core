package Pagesmith::Action::Ensembl::Gene;

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
use Const::Fast qw(const);

sub cache_key {
  my $self = shift;
  my @T    = $self->path_info;
  return @T>1 ? $T[0].q(-).$T[1] : $T[0];
}

sub run {
  my $self     = shift;
  my $species  = $self->next_path_info;
  my $region   = $self->next_path_info;

### Get analysis information!
  my $lnames_str = $self->next_path_info;
  my @lnames = defined($lnames_str) ? split m{:}mxs, $lnames_str : ();
  my $restriction = q();
  if( @lnames ) {
    $restriction = sprintf q( and logic_name in (%s)), join q(,), map { q(?) } @lnames;
  }
  ## no critic (ImplicitNewlines)
  my $sql_analysis = q(
  select  a.analysis_id   as _id,
          a.logic_name    as logic,
         ad.display_label as name
    from analysis as a,
         analysis_description as ad
   where a.analysis_id=ad.analysis_id
  ).$restriction;
  ## use critic
  my $analyses = $self->core_dbh( $species )->selectall_arrayref(
    $sql_analysis, { 'Slice' => {} }, @lnames );
  my @extra_params;
  if( @lnames ) {
    $restriction = sprintf q( and g.analysis_id in (%s)), join q(,), map { q(?) } @{$analyses};
    @extra_params =  map { $_->{'_id'} } @{$analyses};
  }
### End of get analysis information!


  ## no critic (ImplicitNewlines)
  my $sql = q(
  select gsi.stable_id       as id,
         xr.display_label    as label,
         sr.name             as chr,
         g.seq_region_start  as start,
         g.seq_region_end    as end,
         g.seq_region_strand as strand,
         a.logic_name        as logic
    from (
           analysis         as a,
           gene_stable_id   as gsi,
           gene             as g,
           seq_region       as sr
         ) left join xref   as xr on g.display_xref_id=xr.xref_id
   where sr.seq_region_id = g.seq_region_id
     and        g.gene_id = gsi.gene_id
     and          sr.name = ?
     and    g.analysis_id = a.analysis_id
   ).$restriction.q(
   order by g.seq_region_start
  );
  ## use critic

  my $res = $self->core_dbh( $species )->selectall_arrayref( $sql, { 'Slice' => {} }, $region, @extra_params );

### Filter analysis information
  unless(@lnames) {
    my %actual_logic_names = map { ($_->{'logic'},1) } @{$res};
    $analyses = [ grep { $actual_logic_names{ $_->{'logic'} } } @{$analyses} ];
  }

  ## no critic (ImplicitNewlines)
  my $r = $self->core_dbh( $species )->selectrow_arrayref( q(
    select sr.name, sr.length
      from seq_region as sr,
           coord_system as cs
     where sr.name = ?
       and sr.coord_system_id = cs.coord_system_id
       and find_in_set('default_version',cs.attrib)
  ), { 'Slice' => {} }, $region );
  ## use critic
  return $self->json_cache_print( {
    'regions'     => [$r],
    'analyses'    => $analyses,
    'data'        => $res });

}

1;
