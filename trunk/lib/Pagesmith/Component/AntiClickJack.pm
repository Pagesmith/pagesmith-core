package Pagesmith::Component::AntiClickJack;

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

sub execute {
  my $self = shift;
  ## no critic (ImplicitNewlines)
  return q(<style type="text/css" id="antiClickjack">/*<![CDATA[*/
  body{display:none !important;}
/*]]>*/</style>
<script type="text/javascript">// <![CDATA[
  if (self === top) {
    var antiClickjack = document.getElementById("antiClickjack");
    antiClickjack.parentNode.removeChild(antiClickjack);
  } else {
    top.location = self.location;
  }
// ]]></script>);
  ## use critic
}

1;

__END__

h3. Sytnax

<% AntiClickJack %>

h3. Purpose

Adds an anti click jack block in the page!

h3. Notes

* See: https://www.owasp.org/index.php/Clickjacking_Defense_Cheat_Sheet#Defending_legacy_browsers

