package Pagesmith::Component::DelayFile;

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

use base qw(Pagesmith::Component::File);

sub define_options {
  my $self = shift;
  return (
    $self->SUPER::define_options,
    { 'code' => 'sleep', 'defn' => '=i', 'default' => 1, 'description' => 'Length of time to delay response' },
  );
}

sub usage {
  my $self = shift;
  my $usage = $self->SUPER::usage;
  $usage->{'description'} = 'Load a file (via ajax) with a slightly sleep';
  push @{$usage->{'notes'}}, 'DO NOT USE IN ANGER', 'This is really only designed as a demo module to demonstrate ajax methods!';
  return $usage;
}

sub execute {
  my $self = shift;
  sleep $self->option('sleep', 1);
  return $self->SUPER::execute;
}

1;

__END__

<% DelayFile
  -ajax
  -parse
  -delay n
  Filename
%>

h3. Purpose

Include a file within the page

h3. Options

* ajax - Delay loading via AJAX

* parse - Run file back through the directive compiler, so directives in the include will get parsed

h3. Notes

* If file starts with "/" then file is relative to docroot o/w relative to "page"

