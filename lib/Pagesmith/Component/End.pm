package Pagesmith::Component::End;

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

## Stub inserts an "end" to be used with If
##
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$
##
## Todo - add support for nesting (If and End will replace entries withs "show/hide-{n}" && "end-{n}"

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Component);

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(),
    'description' => 'Marks the end of an if block - content is removed if the if is not true',
    'notes'       => [ 'Usually use with <%~ ~%> delayed directive style as usually want to cache content before if applied....' ] ,
    'see_also'    => { 'Pagesmith::Component::If' => 'See notes on If to understand what conditions are possible' },
  };
}

sub execute {
  return '<% end %>';
}

1;

__END__

h3. Sytnax

<% If
  variable
  condition
  value
%>

h3. Purpose

Disables block up to correspoinding <% End %>

h3. Notes

* Variable is either E:environment_variable or H:headers_in

* Condition is one of =|==|eq|equals; !|!=|ne|not_equals; =~|~|contains;
  !~|not_contains; =^|starts; !^|not_starts; =$|ends; !$|not_ends

* 

h3. See Also

* Directive: If

h3. Examples

* <%~ If H:ClientRealm contains my_realm ~%> - Display up to corresponding
  <%~ End ~%> only if in My Realm....
