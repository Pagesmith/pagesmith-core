package Pagesmith::Component::Users::Navigation;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
#| This file is part of the User account management extensions to
#| Pagesmith web framework.
#+----------------------------------------------------------------------
#| The User account management extensions to Pagesmith web framework is
#| free software: you can redistribute it and/or modify it under the
#| terms of the GNU Lesser General Public License as published by the
#| Free Software Foundation; either version 3 of the License, or (at
#| your option) any later version.
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

## Navigation component to insert into pages - mainly to handle admin links!

## Author         : James Smith <js5@sanger.ac.uk>
## Maintainer     : James Smith <js5@sanger.ac.uk>
## Created        : 30th Apr 2014

## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::AjaxComponent Pagesmith::Component::Users);

sub usage {
#@params (self)
#@return (hashref)
## Returns a hashref of documentation of parameters and what the component does!
  my $self = shift;
  return {
    'parameters'  => 'NONE',
    'description' => 'Navigation component',
    'notes'       => [],
  };
}

sub execute {
  my $self = shift;
  return $self->panel(
    '<h3>Navigation</h3>',
    '<ul><li><a href="/action/Users">Home</a></li></ul>',
  ).$self->admin_panel;
}

sub admin_panel {
  my $self = shift;
  return q() unless $self->me;
  my @links;
  push @links, [ '/action/Users_Admin_User', 'Administer users' ] if $self->me->is_admin;
  push @links, [ '/action/Users_Admin_Usergroup', 'Administer usergroups' ] if $self->me->is_admin;
  return q() unless @links;
  return $self->links_panel( 'Admin panel', \@links );
}

1;

__END__
Notes
-----

