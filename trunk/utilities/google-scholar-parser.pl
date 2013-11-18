#!/usr/bin/perl

## Parse google scholar headers from DOI
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

use LWP::Simple qw(get);
use Data::Dumper; ## no xcritic (DebuggingModules)


foreach my $doi ( @ARGV ) {
  my $ref = process($doi);
  ## no critic (LongChainsOfMethodCalls)
  print Data::Dumper->new( [ $ref ], [ 'ref' ] )->Sortkeys(1)->Indent(1)->Terse(1)->Dump; ## no critic (RequireChecked)
  ## use critic
}

## use critic (ExcessComplexity)
sub process {
  my $doi = shift;
  my %simple_map = qw(pmid pubmed doi doi issn issn isbn issn title title);
  my @html = grep { m{\Ameta}mxs } split m{<}mxs, get 'http://dx.doi.org/'.$doi;
  my $reference = { 'doi' => $doi };
  my @authors;
  my $pub = { map {$_=>undef} qw(
    issue firstpage lastpage volume journal_title publication_date online_date
    conference_title dissertation_institution technical_report_institution
    technical_report_number date authors inbook_title
  )};

  foreach ( @html ) {
    my ($k,$v);
    ## no critic (ComplexRegexes)
    if( m{meta\s+(?:.*?\s+)?name="citation_(\w+)"\s+content="\s*(.*?)\s*"}mxs ) {
      $k = $1;
      $v = $2;
    } elsif( m{meta\s+(?:.*?\s+)?content="\s*(.*?)\s*"\s+name="citation_(\w+)"}mxs ) {
      $k = $2;
      $v = $1;
    } else {
      next;
    }
    ## use critic
    if( exists $simple_map{ $k } ) {
      $reference->{$simple_map{$k}}=$v;
    } elsif( exists $pub->{$k} ) {
      $pub->{$k} = $v;
    } elsif( $k eq 'author' ) {
      push @authors, $v;
    }
  }

  augment_reference( $reference, $pub, @authors );
  return $reference;
}

sub augment_reference {
  my ($reference, $pub, @authors ) = @_;
  my $pub_date = $pub->{'publication_date'} || $pub->{'online_date'} || $pub->{'date'} || q(-);

  $reference->{'publication'} = sprintf '%s %s; %s',
    $pub->{'journal_title'}||$pub->{'conference_title'} || $pub->{'inbook_title'} || q(-),
    $pub_date =~ m{(\d{4})}mxs ? $1: q(-),
    join q(),
      $pub->{'volume'} ? "$pub->{'volume'};" : q(),
      $pub->{'issue'}  ? "$pub->{'issue'};"  : q(),
      $pub->{'firstpage'}||q(),
      $pub->{'lastpage'} ? "-$pub->{'lastpage'}":q(),
    ;
  $reference->{'author_list'} = join q(, ), @authors;
  $reference->{'author_list'} = $pub->{'authors'} if exists $pub->{'authors'} && !@authors;
  $reference->{'pub_date'}    = $pub_date;
  return;
}
## use critic

1;
