package Pagesmith::Action::Users::Admin::Usergroup;

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

## Admin table display for objects of type Usergroup in
## namespace Users

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

use base qw(Pagesmith::Action::Users);

sub run {
#@params (self)
## Display admin for table for Usergroup in Users
  my $self = shift;

  return $self->login_required unless $self->user->logged_in;
  return $self->no_permission  unless $self->me && $self->me->is_admin;

  ## no critic (LongChainsOfMethodCalls)
  return $self->my_wrap( q(Users's Usergroup),
    $self
      ->my_table
      ->add_columns(
        { 'key' => 'get_usergroup_id', 'label' => 'Usergroup id', 'format' => 'd' },
        { 'key' => 'get_code', 'label' => 'Code' },
        { 'key' => 'get_name', 'label' => 'Name' },
        { 'key' => 'get_description', 'label' => 'Description' },
        { 'key' => 'get_status', 'label' => 'State' },
        { 'key' => '_edit', 'label' => 'Edit?', 'template' => 'Edit', 'align' => 'c', 'no_filter' => 1,
          'link' => '/form/Users_Admin_Usergroup/[[h:uid]]' },
      )
      ->add_data( @{$self->adaptor( 'Usergroup' )->fetch_all_usergroups||[]} )
      ->render.
    $self->button_links( '/form/Users_Admin_Usergroup', 'Add' ),
  );
  ## use critic
}

1;

__END__
Notes
-----

