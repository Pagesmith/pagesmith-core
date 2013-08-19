package Pagesmith::Form::Element::Time;

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

use base qw( Pagesmith::Form::Element::Date );

sub update_from_apr {
  my( $self, $apr ) = @_;
  my $s = $apr->param( $self->code.'_s' );
  my $x = $apr->param( $self->code.'_x' );
  my $h = $apr->param( $self->code.'_h' );
  $self->{'user_data'}{'second'} = $s if defined $s;
  $self->{'user_data'}{'minute'} = $x if defined $x;
  $self->{'user_data'}{'hour'}   = $h if defined $h;
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
