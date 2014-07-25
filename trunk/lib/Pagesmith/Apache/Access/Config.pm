package Pagesmith::Apache::Access::Config;

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

## Allow access only to people who match criteria in configuration file
## Author         : js5
## Maintainer     : js5
## Created        : 2011-12-08
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Pagesmith::Apache::Access qw(my_handler);
use List::MoreUtils qw(any);

sub handler {
  my $r = shift;
  return my_handler( sub {
    my( $apache_r, $user ) = @_;

    ## First check if a configuration is set for authenticating against groups...
    my @groups   = $apache_r->dir_config->get('X_Pagesmith_AuthGroup');
    return any { $user->in_group( $_ ) }    @groups  if @groups;

    ## Now check for users
    my @users    = $apache_r->dir_config->get('X_Pagesmith_AuthUser');
    return any { $user->username eq $_ }    @users   if @users;

    ## Now check for authentication methods!
    my @methods  = $apache_r->dir_config->get('X_Pagesmith_AuthMethod');
    return any { $user->auth_method eq $_ } @methods if @methods;

    return;
  }, $r );
}

1;
