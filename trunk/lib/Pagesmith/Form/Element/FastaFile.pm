package Pagesmith::Form::Element::FastaFile;

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

use Image::Size qw(imgsize);
use Image::Magick;
use Const::Fast qw(const);
use List::Util qw(sum min max);
use HTML::Entities qw(encode_entities);

const my $MAX_SEQ_TO_LIST        => 5;
const my $MAX_SEQ_LENGTH_TO_SHOW => 200;
const my $WEIGHT_2BP             => 0.1;
const my $WEIGHT_3BP             => 0.01;
const my $WEIGHT_NOBP            => 3;
const my $WEIGHT_2AA             => 0.1;
use English qw(-no_match_vars);

use base qw( Pagesmith::Form::Element::File );
use Pagesmith::Cache;

sub remove_uploaded_file {
  my( $self, $key ) = @_;
  $self->SUPER::remove_uploaded_file( $key );
  return 1;
}

sub extra_file_info {
  my($self,$upload, $content ) = @_;
  ## Quick parse of file to store....

  return unless ${$content};

  ## Split into chunks...
  my @parts = split m{(^>[^\n]+)}mxs, ${$content};

  return unless @parts;

  ## Grab the headers...
  my @headers   = map { m{\A>(.*?)\s*\Z}mxs ? $1 : $_ } grep { m{\A>}mxs } @parts;
  my @sequences = map { { 'name' => q(), 'seq' => $_, $self->res( \$_ ), } } grep { !m{\A>}mxs } @parts;
  ## No sequences...
  return unless @sequences;

  if( $sequences[0]{'length'} ) {
    unshift @headers, 'Unnamed sequence'; ## If sequence before first header then unshift "unnamed" to headers
  } else {
    shift @sequences;                     ## No sequence before first header then remove it...
  }

  my $c = 0; ## Copy name onto each sequence...
  $sequences[ $c++ ]{'name'} = $_ foreach @headers;

  my $n_seq    = @sequences;
  my $t_seq    = sum map { $_->{'length'} } @sequences;
  my $t_raw    = sum map { $_->{'raw_length'} } @sequences;
  my $min_dna  = min map { $_->{'dna'} } @sequences;
  my $min_pep  = min map { $_->{'pep'} } @sequences;
  my $max_dna  = max map { $_->{'dna'} } @sequences;
  my $max_pep  = max map { $_->{'pep'} } @sequences;
  my $mean_dna = ( sum map { $_->{'dna'} } @sequences ) / $n_seq;
  my $mean_pep = ( sum map { $_->{'pep'} } @sequences ) / $n_seq;

  my $caption = sprintf 'There are %d sequences (totalling %d bps/aa) [ %0.4f (%0.4f) %0.4f ] [ %0.4f (%0.4f) %0.4f ] %0.4f', $n_seq, $t_seq,
    $min_dna, $mean_dna, $max_dna,
    $min_pep, $mean_pep, $max_pep,
    $t_raw ? $t_seq/$t_raw : 0
  ;

  if( $n_seq <= $MAX_SEQ_TO_LIST ) {
    $caption .= sprintf '<ul>%s</ul>',
      join q(), map { sprintf '<li>%s (%d bps/aa %0.4f/%0.4f/%0.4f)</li>',
        encode_entities($_->{'name'}),
        $_->{'length'},
        $_->{'dna'},
        $_->{'pep'},
        $_->{'valid'},
      } @sequences;
  }

  return (
    'sequences'     => $n_seq,
    'total_length'  => $t_seq,
    'sequence_info' => \@sequences,
    'caption'       => $caption,
  );

}

sub res {
  my( $self, $seq_ref) = @_;
  my $s = uc ${$seq_ref};
  return ( 'raw_length' => length $s, 'length' => 0, 'dna' => 0, 'pep' => 0, 'valid' => 0 ) unless $s=~ m{[-[:upper:].*]}mxs;
  my $s_saa  = $s =~ tr{ACGTUN\-.}{ACGTUN\-.};
  my $s_daa  = $s =~ tr{IKMRSWYX}{IKMRSWYX};
  my $s_taa  = $s =~ tr{BDHV}{BDHV};
  my $s_prot = $s =~ tr{EFJLOPQZ*}{EFJLOPQZ*};
  my $length = $s_saa+$s_daa+$s_taa+$s_prot;
  my $dna_score = $s_saa + $s_daa * $WEIGHT_2BP + $s_taa * $WEIGHT_3BP - $s_prot * $WEIGHT_NOBP;

  my $pep_score = $length - ($s =~ tr{BJOUZ}{BJOUZ}) * ( 1 - $WEIGHT_2AA );
  return ( 'raw_length' => length $s , 'length' => $length, 'dna' => $dna_score/$length, 'pep' => $pep_score/$length, 'valid' => $length/length $s);
}

sub extra_columns {
  my $self = shift;
  my $prefix = $self->config->{'code'}.q(/).$self->code;
  return (
    { 'key' => 'caption', 'label' => 'Information', 'format' => 'r' },
  );
}

1;
