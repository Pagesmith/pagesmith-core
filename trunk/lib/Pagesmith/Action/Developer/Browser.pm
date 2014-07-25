package Pagesmith::Action::Developer::Browser;

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

## Dumps raw HTML of the file to the browser (syntax highlighted)
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

# Modules used by the code!
use Cwd qw(realpath);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Spec;
use HTML::Entities qw(encode_entities);
use Syntax::Highlight::HTML;

sub run {
  my $self = shift;
  return $self->login_required if !$self->user->logged_in;
  ## no critic (ImplicitNewlines)
  return $self->wrap_rhs( 'File browser',
   '<div class="panel make-wide"><h2>File browser</h2>
      <div id="jQueryFileTop"></div>
      <hr class="clear" />
      <div id="jQueryFileBox"></div>
    </div>',
   '<div class="panel"><h3>Browser</h3><div id="jQueryFileTree" style="padding:0 5px"></div></div>',
  )->push_javascript_files( '/core/js/developer/jqueryfiletree.js' )
   ->push_css_files( '/core/css/developer/jqueryfiletree.css' )->ok;
  ## use critic
}
1;
