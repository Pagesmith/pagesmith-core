package Pagesmith::Action::Users::Me;

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

## Admin table display for objects of type User in
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
## Display admin for table for User in Users
  my $self = shift;
  return $self->login_required unless $self->user->logged_in;

  return $self->redirect_secure unless $self->is_secure;

  ## no critic (LongChainsOfMethodCalls)

  my $extra;

  $extra .= '<p><a class="btt" href="/users/UpdateDetails">Update details</a></p>' if $self->user->auth_method eq 'user_db';

  my $groups = q(<p>You are not currently the member of any groups</p>);
  if( $self->user->groups ) {
    $groups = sprintf '<ul>%s</ul>', join q(), map { sprintf '<li>%s</li>', $_ } sort $self->user->groups;
  }
  return $self->my_wrap_no_heading( q(My details),
    sprintf '
<div class="balance">
<div class="col1">
  <div class="panel">
    <h3>My details</h3>
    %s
  </div>
</div>
<div class="col2">
  <div class="panel">
    <h3>My groups</h3>
    %s
  </div>
</div>
</div>',
    $self->twocol
      ->add_entry( 'Username', $self->encode( $self->user->email ) )
      ->add_entry( 'Name',     $self->encode( $self->user->name  ) )
      ->add_entry( 'Method',   $self->user->auth_method )
      ->render.
    $extra, $groups,
  );
  ## use critic
}

1;

__END__
Notes
-----

