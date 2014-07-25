package Pagesmith::Component::Date;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
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

## Return last modified date of file...
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

use Date::Format qw(time2str);

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'zone',  'defn' => '=s',                                       'description' => 'Time zone' },
    { 'code' => 'format','defn' => '=s', 'default' => '%a, %d %b %Y %H:%M %Z', 'description' => 'Standard time2str date format' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(),
    'description' => 'Display the current time',
    'notes'       => [],
  };
}


sub execute_time {
  my ($self, $time ) = @_;
  return time2str( $self->option( 'format' ), $time, $self->option( 'zone' ) );
}

sub execute {
  my $self = shift;
  return $self->execute_time( time );
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

