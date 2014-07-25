package Pagesmith::Component::Edit::Diff;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

use base qw(Pagesmith::Component Pagesmith::Support::Edit);

use Cwd qw(cwd realpath);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Basename qw(dirname);
use File::Spec;
use HTML::Entities qw(encode_entities);

sub define_options {
  my $self = shift;
  return (
    $self->click_ajax_option,
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{dir}',
    'description' => 'Display table of file information for this directory',
    'notes'       => [],
  };
}

sub ajax {
  my $self = shift;
  return $self->click_ajax;
}

sub no_permission_error {
  return '<p>No permission</p>';
}

sub execute {
  my $self = shift;
  return $self->no_permission_error unless $self->site_is_editable;  ## Edit is not enabled!
  return $self->no_permission_error unless $self->is_valid_user;     ## No valid user or user does not have permission to edit!

  my $root = $self->r->document_root;
  ( my $path = $self->next_par||q() ) =~ s{\A/}{}mxs;
  my $full_path = realpath( File::Spec->rel2abs( $path, $root ) );
  $full_path .=q(/) unless $full_path =~ m{/\Z}mxs;
  return $self->no_permission_error unless -e $full_path;    ## Check exists and database
  return $self->no_permission_error unless -d $full_path;    ## Not a directory!
  return $self->no_permission_error unless substr( $full_path, 0, length $root ) eq $root; ## Not in tree!
  ## We need to do some file permission checking here!
  return '<p>Boo!</p>';
}

1;

__END__

<% File
  -ajax
  -parse
  Filename
%>

h3. Purpose

Include a file within the page

h3. Options

* ajax - Delay loading via AJAX

* parse - Run file back through the directive compiler, so directives in the include will get parsed

h3. Notes

* If file starts with "/" then file is relative to docroot o/w relative to "page"

