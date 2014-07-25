package Pagesmith::Form::Element::Time;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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

##
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use POSIX qw(strftime);

use base qw( Pagesmith::Form::Element::Date );

sub update_from_apr {
  my( $self, $apr ) = @_;
  my $s = $apr->param( $self->code.'_s' );
  my $x = $apr->param( $self->code.'_x' );
  my $h = $apr->param( $self->code.'_h' );

  my $date = $apr->param( $self->code );
  if( defined $date ) {
    my @time = $self->get_date_array( $date );
    if( @time ) {
      my ($x_h,$x_x,$x_s) = split m{:}mxs, strftime('%H:%M:%S',@time);
      $h ||= $x_h;
      $x ||= $x_x;
      $s ||= $x_s;
    }
  }

  $self->{'user_data'} = [{
    'second'  => defined $s ? $s : undef,
    'minute'  => defined $x ? $x : undef,
    'hour'    => defined $h ? $h : undef,
  }];
  return;
}

sub render_widget {
  my $self = shift;
  return $self->render_widget_time;
}

sub render_widget_readonly {
  my $self = shift;
  return $self->render_readonly_time;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_time' );
  return $self;
}

sub scalar_value {
  my $self = shift;
  return $self->get_time_value;
}

1;
