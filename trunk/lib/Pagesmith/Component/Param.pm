package Pagesmith::Component::Param;

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

## Insert a "inpur param" into the page
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

use URI::Escape qw(uri_escape_utf8);
use HTML::Entities qw(encode_entities);    ## HTML entity escaping

use Pagesmith::Core qw(fullescape);

sub usage {

  my $self = shift;

  return {
    'parameters'  => q({parameter_name} {default_value}),
    'description' => 'Displays the contents of the CGI parameter parameter_name or default_value',
    'notes'       => [ q(By default the value is HTML encoded), q(Don't use the r option in anger as it is dangerous!) ],
  };
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'u', 'defn' => q(), 'description' => 'URL encode string' },
    { 'code' => 'r', 'defn' => q(), 'description' => 'Do not encode string' },
    { 'code' => 'f', 'defn' => q(), 'description' => 'Fully encode string - i.e. all characters get converted' },
  );
}

sub execute {
  my $self = shift;
  my ( $variable, $default ) = $self->pars;

  my $val = $self->page->apr->param($variable);
  $val = $default unless defined $val;

  $val =
      $self->option('u') ? ( $self->option('f') ? fullescape($val) : uri_escape_utf8($val) )
    : $self->option('r') ? $val
    : $self->option('f') ? encode_entities( $val, q(^~) )
    :                      encode_entities( $val );
  return $val;
}
1;

__END__

<% Param
  -(u|r|f)?
  parameter
  default_value
%>

h3. Purpose

Include the value of a cgi

h3. Options

* u - URL escape the parameters

* r - RAW do no encoding - here be dragons

* f - Full encode all characters as numeric entities

h3. Notes

* default (no switches) is to perform entity encoding
