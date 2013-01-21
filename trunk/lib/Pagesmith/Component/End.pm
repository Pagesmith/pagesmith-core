package Pagesmith::Component::End;

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
