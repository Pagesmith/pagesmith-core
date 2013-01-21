package Pagesmith::Component::TmpRef;

## Component to create a temp ref
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

use base qw(Pagesmith::Component);

use Cwd qw(cwd realpath);
use File::Basename;
use File::Spec;
use HTML::Entities qw(encode_entities);
use utf8;


sub usage {
  my $self = shift;
  return {
    'parameters'  => '{abstract=s@}',
    'description' => 'Create a reference which is displayed by the references directive <% References %>',
    'notes'       => [ q(If supplied abstract is anything which isn't an option) ],
  };
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'pub_date',           'defn' => '=s',  'description' => 'Publication date - see pubmed XML format' },
    { 'code' => 'year',               'defn' => '=s',  'description' => 'Publication year - see pubmed XML format' },
    { 'code' => 'journal',            'defn' => '=s',  'description' => 'Journal - see pubmed XML format' },
    { 'code' => 'month',              'defn' => '=s',  'description' => 'Publication month - see pubmed XML format' },
    { 'code' => 'day',                'defn' => '=s',  'description' => 'Publication day - see pubmed XML format' },
    { 'code' => 'title',              'defn' => '=s',  'description' => 'Title - see pubmed XML format' },
    { 'code' => 'key',                'defn' => '=s',  'description' => 'Key - to use if cited' },
    { 'code' => 'url',                'defn' => '=s',  'description' => 'URL - see pubmed XML format' },
    { 'code' => 'pages',              'defn' => '=s',  'description' => 'Page numbers - see pubmed XML format' },
    { 'code' => 'issue',              'defn' => '=s',  'description' => 'Issue - see pubmed XML format' },
    { 'code' => 'isbn',               'defn' => '=s',  'description' => 'ISBN number' },
    { 'code' => 'volume',             'defn' => '=s',  'description' => 'Volume - see pubmed XML format' },
    { 'code' => 'authors_incomplete', 'defn' => '=s',  'description' => 'True if authors incomplete - see pubmed XML format' },
    { 'code' => 'doi',                'defn' => '=s',  'description' => 'DOI id - see pubmed XML format' },
    { 'code' => 'pmc',                'defn' => '=s',  'description' => 'PMC id - see pubmed XML format' },
    { 'code' => 'author',             'defn' => '=s@', 'description' => 'Authors (may have multiple values) - see pubmed XML format' },
  );
}


sub execute {
  my $self = shift;

  ## Get/create the temporary references store on the page object so it can be picked up
  ## by the references directive

  my $ref_arr = $self->init_store( 'tmp_refs', [] );

  my $reference_data = {'ids'=>{}};
  foreach (qw(doi pmc)) {
    $reference_data->{'ids'}{$_} = $self->option($_);
  }

  foreach (qw(pub_date isbn year journal month day title key url pages issue volume authors_incomplete)) {
    $reference_data->{$_} = $self->option($_) if defined $self->option($_);
  }

  $reference_data->{'abstract'} = join q( ), $self->pars;
  my @authors = map { { 'name' => $_ } } $self->option('author');
  $reference_data->{'authors'} = \@authors;

  push @{$ref_arr}, $reference_data;
  return q();
}

1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

