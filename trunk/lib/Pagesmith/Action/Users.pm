package Pagesmith::Action::Users;

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

## Base class for actions in Users namespace

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

use base qw(Pagesmith::Action Pagesmith::Support::Users);

sub admin_wrap {
  my ( $self, $title, @body ) = @_;
  return $self
    ->html
    ->set_navigation_path( '/my_path' )
    ->wrap_rhs(
      $title,
      $self->panel( '<h2>Users</h2>
                     <h3>'.$self->encode( $title ).'</h3>',
                    @body,
      ),
      '<% Users_Navigation -ajax %>',
    )
    ->ok;
}

sub my_wrap {
  my ( $self, $title, $body ) = @_;
  return $self->wrap( $title, $body )->ok;
}

sub my_wrap_no_heading {
  my ( $self, $title, $body ) = @_;
  return $self->wrap_no_heading( $title, $body )->ok;
}

sub run {
  my $self = shift;
  return $self->my_wrap( 'Users test',
    $self->panel( '<p>Base action file created successfully</p>' ),
  );
}

1;

__END__
Notes
-----

This is the generic Action code for all the code with objects in the
namespace "Users".

