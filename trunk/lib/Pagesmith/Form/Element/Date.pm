package Pagesmith::Form::Element::Date;

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

use base qw( Pagesmith::Form::Element::DateTime );

sub populate_object_values {

}

sub populate_user_values {

}

sub update_from_apr {
  my( $self, $apr ) = @_;
  my $d = $apr->param( $self->code.'_d' );
  my $m = $apr->param( $self->code.'_m' );
  my $y = $apr->param( $self->code.'_y' );
  $self->{'user_data'}{'day'}   = $d if defined $d;
  $self->{'user_data'}{'month'} = $m if defined $m;
  $self->{'user_data'}{'year'}  = $y if defined $y;
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
