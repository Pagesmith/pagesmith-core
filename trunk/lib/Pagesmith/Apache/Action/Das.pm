package Pagesmith::Apache::Action::Das;

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

## Apache handler for CGP action classes
## Author         : js5,dmb,pg6
## Maintainer     : pg6, dmb, nb7
## Created        : 2011-05-04
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$


use strict;
use warnings;
use utf8;

use version qw(qv);our $VERSION = qv('0.1.0');

use Const::Fast qw(const);

const my %LOOKUP => map { lc $_ => $_ } qw(Sources DSN Flush Summary Status);

use Pagesmith::Apache::Action qw(my_handler);

sub handler {
  my $r = shift;
  # return($path_munger_sub_ref,$request)
  # see Pagesmith::Action::_handler to find out how this works
  # briefly:  munges the url path using the sub {} defined here
  # to get the action module
  # then calls its run() method and returns a status value

  return my_handler(
    sub {
      my ( $apache_r, $path_info ) = @_;
      if( $path_info->[0] eq 'das' ) {
        shift @{$path_info};
        if( @{$path_info} ) {
          my $k = lc $path_info->[0];
          if( exists $LOOKUP{ $k } ) {
            $path_info->[0] = "Das_$LOOKUP{ $k }";
          } else {
            unshift @{$path_info}, 'Das';
          }
        } else {
          unshift @{$path_info}, 'Das';
        }
      }
      return;
    },
    $r,
  );
}

1;
