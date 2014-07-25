package Pagesmith::Form::Element::Date;

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

use base qw( Pagesmith::Form::Element::DateTime );

sub populate_object_values {

}

sub populate_user_values {

}

sub update_from_apr {
  my( $self, $apr ) = @_;
  my $date = $apr->param( $self->code );
  my $d = $apr->param( $self->code.'_d' );
  my $m = $apr->param( $self->code.'_m' );
  my $y = $apr->param( $self->code.'_y' );
  if( defined $date ) {
    my @time = $self->get_date_array( $date );
    if( @time ) {
      my ($x_y,$x_m,$x_d) = split m{:}mxs, strftime('%Y:%m:%d',@time);
      $d ||= $x_d;
      $m ||= $x_m;
      $y ||= $x_y;
    }
  }
  $d = $self->limit_day( $d,$m,$y );

  $self->{'user_data'} = [{
    'day'     => defined $d ? $d : undef,
    'month'   => defined $m ? $m : undef,
    'year'    => defined $y ? $y : undef,
  }];

  return;
}

sub render_widget {
  my $self = shift;
  return $self->render_widget_date.$self->req_opt_string;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_date' );
  return $self;
}

sub render_widget_readonly {
  my $self = shift;
  my $value = $self->render_readonly_date;
  $value = q(--) if $value eq q();
  return $value;
}

sub scalar_value {
  my $self = shift;
  return $self->get_date_value;
}

1;
