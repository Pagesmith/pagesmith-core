package Pagesmith::Utils::CodeWriter::Action;

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

## Package to write packages etc!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Mon, 11 Feb 2013
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Utils::CodeWriter);

sub base_class {
  my $self = shift;
  my $filename = sprintf '%s/Action%s.pm',$self->base_path,$self->ns_path;

## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::Action::%1$s;

## Base class for actions in %1$s namespace
%2$s
use base qw(Pagesmith::Action Pagesmith::Support::%1$s);

sub my_wrap {
  my( $self, @pars ) = @_;
  return $self->html->wrap( @pars )->ok;
}

1;
),
    $self->namespace,    ## %1$
    $self->boilerplate,  ## %2$
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

sub admin_wrapper {
  my $self = shift;
  my $filename = sprintf '%s/Action%s/Admin.pm',$self->base_path,$self->ns_path;

  my @tab_def = q();
  foreach my $type ( $self->objecttypes ) {
    push @tab_def, sprintf q(    ->add_tab( 't_%s', '%s', '<%% %s_Admin_%s -ajax %%>' )),
      $self->ky($type), $self->hr($type), $self->ns_comp, $self->comp($type);
  }
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::Action::%1$s::Admin;

## Admininstration wrapper for objects in namespace %1$s
%2$s
use base qw(Pagesmith::Action::%1$s);

sub run {
#@params (self)
## Display tabs containing ajax containers for each of the components...
  my $self = shift;
  return $self->login_required unless $self->user->logged_in;

  ## no critic (LongChainsOfMethodCalls)
  my $tabs = $self->tabs
    ->add_tab( 't_0', 'Information', '<p>Put stuff here</p>' )%3$s;
  ## use critic;
  return $self->my_wrap( 'Admin for %1$s', $tabs->render );
}

1;

__END__
),
    $self->namespace,      # %1$s
    $self->boilerplate,    # %2$s
    join qq(\n), @tab_def, # %3$s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

sub admin {
  my ($self,$type) = @_;
  my $filename = sprintf '%s/Action%s/Admin/%s.pm',$self->base_path,$self->ns_path, $self->fp( $type );
  my $add_link = sprintf '/form/%s_Admin_%s', $self->ns_comp, $self->fp( $type );

## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::Action::%1$s::Admin::%2$s;

## Admininstration action for objects of type %2$s
## in namespace %1$s
%3$s
use base qw(Pagesmith::Action::%1$s);

sub run {
#@params (self)
## Display admin for table for %2$s in %1$s
  my $self = shift;
  return $self->login_required unless $self->user->logged_in;

  $self->attach_user;

  ## Display tags for a search box!
%4$s
  return $self->my_wrap( 'Admin for %2$s in %1$s',
    $table->render.'<p><a href="%5$s">Add</a></p>' );
}

1;

__END__
),
    $self->namespace,      # %1$s
    $type,                 # %2$s
    $self->boilerplate,    # %3$s
    $self->admin_table( $type ), # %4$s
    $add_link              # %5$s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

1;

