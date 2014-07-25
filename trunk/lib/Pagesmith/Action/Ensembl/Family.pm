package Pagesmith::Action::Ensembl::Family;

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

const my $DEFAULT_FAMILY_SIZE => 5;

sub cache_key {
  my $self = shift;
  my @T    = $self->path_info;
  return $T[0].q(-).$T[1];
}

sub run {
  my $self   = shift;
  my $species   = $self->next_path_info;
  my $stable_id = $self->next_path_info;
  if( $species eq 'All' && $stable_id ) {
    my ($desc) = $self->compara_dbh->selectrow_array( q(select description from family where stable_id = ?),{},$stable_id );
    if( !$desc ) {
      return $self->json_cache_print( {
        'name'        => 'Unknown family: '.$self->encode($stable_id),
        'description' => q(The family you selected doesn't exist or contains no genes),
        'data'        => [],
      });
    }
    ## no critic (ImplicitNewlines)
    return $self->json_cache_print(
      $self->compara_dbh->selectall_arrayref( q(
        select t.name as species, count(*) as members
          from ncbi_taxa_name        as t,
               family                as f,
               family_member         as fm,
               member                as m
         where   f.family_id = fm.family_id
           and  fm.member_id = m.member_id
           and m.source_name = 'ENSEMBLGENE'
           and    m.taxon_id = t.taxon_id
           and  t.name_class = 'scientific name'
           and   f.stable_id = ?
         group by t.name
         order by t.name
      ), { 'Slice' => {} }, $stable_id) );
    ## use critic
  }

  my $compara   = $self->compara;
  my $taxon_id  = $self->taxon_id( $species );
  if( !$stable_id || $stable_id =~ m{\A\d+\Z}mxs ) {
    my $count = $stable_id || $DEFAULT_FAMILY_SIZE;
    ## no critic (ImplicitNewlines)
    return $self->json_cache_print(
      $self->compara_dbh->selectall_arrayref( q(
        select f.stable_id as id, count(*) as members
          from family                as f,
               family_member         as fm,
               member                as m
         where   f.family_id = fm.family_id
           and  fm.member_id = m.member_id
           and m.source_name = 'ENSEMBLGENE'
           and    m.taxon_id = ?
         group by f.stable_id
        having members>=?
         order by members desc, f.stable_id
      ), { 'Slice' => {} }, $taxon_id, $count ));
    ## use critic
  }
  my ($desc) = $self->compara_dbh->selectrow_array( q(select description from family where stable_id = ?),{},$stable_id );
  if( !$desc ) {
    return $self->json_cache_print( {
      'name'        => 'Unknown family: '.$self->encode($stable_id),
      'description' => q(The family you selected doesn't exist or contains no genes),
      'data'        => [],
    });
  }
  ## no critic (ImplicitNewlines)
  my @gene_ids = map { @{$_} } @{$self->compara_dbh->selectall_arrayref( q(
    select m.stable_id
      from family        as f,
           family_member as fm,
           member        as m
     where    f.stable_id = ?
     and      f.family_id = fm.family_id
     and     fm.member_id = m.member_id
     and    m.source_name = 'ENSEMBLGENE'
     and       m.taxon_id = ?
  ), {}, $stable_id, $taxon_id )};

  my $sql = sprintf q(
  select gsi.stable_id       as id,
         xr.display_label    as label,
         sr.name             as chr,
         g.seq_region_start  as start,
         g.seq_region_end    as end,
         g.seq_region_strand as strand
    from (
           gene_stable_id   as gsi,
           gene             as g,
           seq_region       as sr
         ) left join xref   as xr on g.display_xref_id=xr.xref_id
   where sr.seq_region_id = g.seq_region_id
     and        g.gene_id = gsi.gene_id
     and    gsi.stable_id in (%s)
   order by sr.name,
            g.seq_region_start
  ), join q(,), map { q(?) } @gene_ids;
  ## use critic

  return $self->json_cache_print( {
    'name'        => $stable_id,
    'description' => $desc,
    'data'        => $self->core_dbh( $species )->selectall_arrayref( $sql, { 'Slice' => {} }, @gene_ids ),
  });
}

1;
