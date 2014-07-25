package Pagesmith::Component::JsFile;

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

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'embed', 'description' => 'If included embed the Javascript in the page' },
  );
}

sub usage {
  my $self = shift;
  return {
    'paramters'   => q({name=s}+),
    'description' => 'Push javascript files into the page (either as embed files or src links)',
    'notes'       => q({name} name of file),
  };
}

sub my_cache_key {
  my $self = shift;
  return;
}

sub execute {
  my $self = shift;
  my @files = $self->pars;

  $self->embed_javascript_files if $self->option('embed');
  $self->push_javascript_files( $self->pars );
  return q();
}

1;

__END__

Purpose
-------

Embed or link to multiple JS files - embedding can improve performance for small amounts
of JS which occur on a single page, e.g. home page, as it minimizes requests

See Also
--------

* Directive: CssFile
* Module:    Pagesmith::Page

Developer Notes
---------------

* Extends normal File component - which does access checks etc;
* Embeds content into page - to be picked up by the decorate in Pagesmith::Page;
* The code push entries into the pnotes( 'js_files' ) array;
* embed flag updates pnotes( 'embed_js' ).


