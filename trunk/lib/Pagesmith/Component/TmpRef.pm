package Pagesmith::Component::TmpRef;

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

