package Pagesmith::Action::Ensembl;

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

use base qw(Pagesmith::Action);

use DBI;

my @core = qw(
anolis_carolinensis_core_58_1b
bos_taurus_core_58_4g
caenorhabditis_elegans_core_58_210
callithrix_jacchus_core_58_321
canis_familiaris_core_58_2n
cavia_porcellus_core_58_3b
choloepus_hoffmanni_core_58_1b
ciona_intestinalis_core_58_2n
ciona_savignyi_core_58_2i
danio_rerio_core_58_8d
dasypus_novemcinctus_core_58_2b
dipodomys_ordii_core_58_1d
drosophila_melanogaster_core_58_513b
echinops_telfairi_core_58_1h
equus_caballus_core_58_2e
erinaceus_europaeus_core_58_1f
felis_catus_core_58_1g
gallus_gallus_core_58_2n
gasterosteus_aculeatus_core_58_1k
gorilla_gorilla_core_58_3a
homo_sapiens_core_58_37c
loxodonta_africana_core_58_3a
macaca_mulatta_core_58_10m
macropus_eugenii_core_58_1a
microcebus_murinus_core_58_1c
monodelphis_domestica_core_58_5j
mus_musculus_core_58_37k
myotis_lucifugus_core_58_1h
ochotona_princeps_core_58_1d
ornithorhynchus_anatinus_core_58_1l
oryctolagus_cuniculus_core_58_2a
oryzias_latipes_core_58_1j
otolemur_garnettii_core_58_1f
pan_troglodytes_core_58_21m
pongo_pygmaeus_core_58_1d
procavia_capensis_core_58_1d
pteropus_vampyrus_core_58_1d
rattus_norvegicus_core_58_34z
saccharomyces_cerevisiae_core_58_1j
sorex_araneus_core_58_1f
spermophilus_tridecemlineatus_core_58_1h
sus_scrofa_core_58_9b
taeniopygia_guttata_core_58_1d
takifugu_rubripes_core_58_4l
tarsius_syrichta_core_58_1d
tetraodon_nigroviridis_core_58_8c
tupaia_belangeri_core_58_1g
tursiops_truncatus_core_58_1d
vicugna_pacos_core_58_1d
xenopus_tropicalis_core_58_41o
);

my $core = { map { m{\A(.*)_core_}mxs ? (ucfirst $1,$_) : ($_,$_) } @core };

sub compara {
  return 'ensembl_compara_58:ensdb-1-14:5304';
}

sub compara_dbh {
  my $self = shift;
  return $self->{'_dbh'}{'compara'} ||= DBI->connect('dbi:mysql:'.$self->compara,'ensro');
}

sub core {
  my( $self, $species ) = @_;
  return $core->{ $species }.':ensdb-1-14:5304';
}
sub core_dbh {
  my( $self, $species ) = @_;
  return $self->{'_dbh'}{qq(core:$species)} ||= DBI->connect('dbi:mysql:'.$self->core($species),'ensro');
}

my $taxon_id_cache;
sub taxon_id {
  my( $self, $species ) = @_;
  unless( exists $taxon_id_cache->{$species} ) {
    ( my $x = $species ) =~ tr{_}{ };
    ($taxon_id_cache->{$species}) = $self->compara_dbh->selectrow_array( 'select taxon_id from ncbi_taxa_name where name = ?', {}, $x )||0;
  }
  return $taxon_id_cache->{$species};
}

sub cache_key {
  my $self = shift;
  my @Q = $self->path_info;
  return $Q[0];
}

sub run {
  my $self = shift;
  my $sub  = $self->next_path_info;
  if( $sub eq 'species' ) {
    ## no critic (ComplexMappings)
    return $self->json_cache_print( [
      map { (my $x = $_) =~ s{_}{ }mxgs; { 'name' => $_, 'label' => $x } }
      map { $_ =~ m{\A(.*)_core_\d.*\Z}mxs ? ucfirst lc $1 : () }
      @core ] );
    ## use critic
  }
  return $self->json_cache_print( [] );
}
1;
