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

sub execute {
  my $self = shift;

  my $ref_arr = $self->init_store( 'tmp_refs', [] );

  my $reference_data = {'ids'=>{}};
  foreach (qw(doi pmc)) {
    $reference_data->{'ids'}{$_} = $self->option($_);
  }
  foreach (qw(pub_date year journal month day abstract title key url pages issue volume authors_incomplete)) {
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

