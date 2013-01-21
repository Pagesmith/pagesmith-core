package Pagesmith::Component::CssFile;

## Including a file!
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

use base qw(Pagesmith::Component::File);

use Cwd qw(cwd realpath);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use HTML::Entities qw(encode_entities);

sub my_cache_key {
  my $self = shift;
  return;
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'embed', 'description' => 'Embed CSS in page' },
    { 'code' => 'ie67',  'description' => 'Embed wrapped in conditional comments so only included in IE 6 and 7' },
    { 'code' => 'ie678', 'description' => 'Embed wrapped in conditional comments so only included in IE less than version 9' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => q({name=s}+),
    'description' => 'Push CSS files into the page (either as embed files or src links)',
    'notes'       => q({name} name of file),
  };
}


sub execute {
  my $self = shift;

  $self->embed_css_files if $self->option('embed');

  if( $self->option( 'ie67' ) ) {
    $self->push_ie67_css_files( $self->pars );
  } elsif( $self->option( 'ie678' ) ) {
    $self->push_ie678_css_files( $self->pars );
  } else {
    $self->push_css_files( $self->pars );
  }
  return q();
}

1;
__END__

h3. Syntax

<% CssFile
   -embed
   -ie=s
   (files)+
%>

h3. Purpose

Embed or link to multiple CSS files - embedding can improve performance for small amounts
of CSS which occur on a single page, e.g. home page, as it minimizes requests

h3. Options

* embed (opt default false) - whether to link to files or embed them

h3. Notes

* Extends normal File component - which does access checks etc

h3. See Also

* Directive: JsFile

h3. Developer Notes

* consider how to do compression efficiently (possibly using auto compressed versions of CSS)

