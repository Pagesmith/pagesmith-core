package Pagesmith::Action::Ensembl::Karyotype;

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

sub cache_key {
  my $self = shift;
  my @T    = $self->path_info;
  return $T[0] if @T<2;
  return "$T[0]:$T[1]";
}

sub run {
  my $self      = shift;
  my $species   = $self->next_path_info;
  my($chr_coord_sys_id) = $self->core_dbh( $species )->selectrow_array(
    q(select * from coord_system where name = "chromosome" and FIND_IN_SET( 'default_version', attrib )) );
  my $chr       = $self->next_path_info;
  return $self->json_cache_print([]) unless $chr_coord_sys_id;
  my $restriction = q();
  my @extra_pars;
  if( $chr ) {
    $restriction = ' and name = ?';
    push @extra_pars, $chr;
  }
  my @chr_data =
    map { $_->[0] }
    sort { $a->[1] cmp $b->[1] }
    map { [ $_, $_->{'name'} =~ m{\A(\d+)(.*)\Z}mxs ? sprintf( '%06d%s', $1, $2 ) : $_->{'name'} ]}
    @{ $self->core_dbh( $species )->selectall_arrayref(
      q(select seq_region_id, name, length from seq_region where coord_system_id = ?).$restriction,
      { 'Slice' => {} },
      $chr_coord_sys_id, @extra_pars,
    )};

  ## no critic (ImplicitNewlines)
  my %haps = map { @{$_} } @{ $self->core_dbh( $species )->selectall_arrayref(
    q(select seq_region_id,1
        from assembly_exception
       where exc_type ="HAP"),
  )};
  ## use critic
  my $res = [];
  my $ids = {};
  foreach my $row ( @chr_data ) {
    next if $haps{ $row->{'seq_region_id'} };
    next if $row->{'name'} =~ m{Un}mxs;
    next if $row->{'name'} =~ m{unplaced}mxs;
    next if $row->{'name'} =~ m{cutchr}mxs;
    next if $row->{'name'} =~ m{random}mxs;
    $ids->{$row->{'seq_region_id'}} = @{$res};
    push @{$res}, { 'name' => $row->{'name'}, 'len' => $row->{'length'}, 'bands' => [] };
  }

  my $bands = $self->core_dbh( $species )->selectall_arrayref(
    q(select seq_region_id, seq_region_start, band, stain from karyotype order by seq_region_id, seq_region_start),
    { 'Slice' => {} },
  );

  foreach my $r (@{$bands}) {
    next unless exists $ids->{$r->{'seq_region_id'}};
    push @{ $res->[$ids->{$r->{'seq_region_id'}}]->{'bands'} }, { 'band'=> $r->{'band'}, 'stain' => $r->{'stain'}, 'start' => $r->{'seq_region_start'} };
  }

  return $self->json_cache_print( $res );
}

1;
