package Pagesmith::Component::AntiClickJack;

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
  return {
    'parameters'  => q(),
    'description' => q(Inserts an AntiClickJack HTML/CSS/Javascript blob in the top of the page),
    'notes'       => [ 'The purpose of this module is to stop the pages being embedded inside frames or iframes' ],
  };
}

sub execute {
  my $self = shift;
  ## no critic (ImplicitNewlines)
  return q(<!-- OK --><style type="text/css" id="acj">/*<![CDATA[*/
  body{display:none !important;}
/*]]>*/</style>
<!-- OK --><script type="text/javascript">// <![CDATA[
  if (self === top) {
    var acj_obj = document.getElementById("acj");
    acj_obj.parentNode.removeChild(acj_obj);
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

