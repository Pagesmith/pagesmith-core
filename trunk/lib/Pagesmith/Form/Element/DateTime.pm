package Pagesmith::Form::Element::DateTime;

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

use Readonly qw(Readonly);
Readonly my $YEAR_OFFSET    => 1900;
Readonly my $DAYS_IN_MONTH  => 31;
Readonly my $MONTHS_IN_YEAR => 12;
Readonly my $HOURS_IN_DAY   => 24;
Readonly my $SIXTY          => 60;

use base qw( Pagesmith::Form::Element );

use POSIX qw(strftime);
use Date::Format qw(time2str);

use HTML::Entities qw(encode_entities);

my @months = qw(January February March April May June July August September October November December);

sub _init {
  my $self = shift;
  $self->blank;
  return $self;
}
sub year_range {
  my( $self, $start, $end ) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime;
  $self->{'use_range'} = 1;
  $self->{'start_range'} = defined $start ? $start : $year+$YEAR_OFFSET;
  $self->{'end_range'}   = defined $end   ? $end   : $year+$YEAR_OFFSET;
  return $self;
}

sub value {
  my $self = shift;
  my $return = {};
  $self->{'user_data'}||={};
  foreach ( qw(second minute hour day month year) ) {
    $return->{$_} = exists $self->{'user_data'}{$_} && defined $self->{'user_data'}{$_} ?  $self->{'user_data'}{$_}
                  : exists $self->{'obj_data' }{$_} && defined $self->{'obj_data' }{$_} ?  $self->{'obj_data' }{$_}
                  : exists $self->{'default'  }{$_} && defined $self->{'default'  }{$_} ?  $self->{'default'  }{$_}
                  : 0
                  ;
  }
  return $return;
}

sub get_date_value {
  my $self = shift;
  my $hash = $self->value;
  return sprintf '%04d-%02d-%02d', $hash->{'year'}||0, $hash->{'month'}||0, $hash->{'day'}||0;
}

sub get_time_value {
  my $self = shift;
  my $hash = $self->value;
  return sprintf '%02d:%02d:%02d', $hash->{'hour'}||0, $hash->{'minute'}||0, $hash->{'second'}||0;
}

sub get_date_time_value {
  my $self = shift;
  return $self->get_date_value.q( ).$self->get_time_value;
}

sub scalar_value {
  my $self = shift;
  return $self->get_date_time_value;
}

sub use_3letter_month {
  my $self = shift;
  $self->{'3letter'} = 1;
  return $self;
}

sub three_letter {
  my $self = shift;
  return $self->{'3letter'};
}

sub blank {
  my $self = shift;
  $self->set_default_value( { 'second' => undef, 'minute' => undef, 'hour' => undef,
                        'day'    => undef, 'month'  => undef, 'year' => undef } );
  return $self;
}

sub now {
  my $self = shift;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime;
  $self->set_default_value( { 'second' => $sec,  'minute' => $min,  'hour' => $hour,
                        'day'    => $mday, 'month' => $mon+1, 'year' => $year+$YEAR_OFFSET } );
  return $self;
}

sub today {
  my $self = shift;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime;
  $self->set_default_value( { 'second' => 0,  'minute' => 0,  'hour' => 0,
                        'day'    => $mday, 'month' => $mon+1, 'year' => $year+$YEAR_OFFSET } );
  return $self;
}

sub set_obj_data {
  my( $self, $value ) = @_;
  if( ref $value eq 'HASH' ) {
    $self->{'obj_data'} = $value;
  } else {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = $self->munge_date_time_array( $value );
    $self->SUPER::set_obj_data({
      'second' => $sec,  'minute' => $min,  'hour' => $hour,
      'day'    => $mday, 'month' => $mon+1, 'year' => $year+$YEAR_OFFSET });
  }
  return $self;
}

sub update_from_apr {
  my( $self, $apr ) = @_;
  $self->{'user_data'}{'day'}   = $apr->param( $self->code.'_d' );
  $self->{'user_data'}{'month'} = $apr->param( $self->code.'_m' );
  $self->{'user_data'}{'year'}  = $apr->param( $self->code.'_y' );
  $self->{'user_data'}{'second'}   = $apr->param( $self->code.'_s' );
  $self->{'user_data'}{'minute'} = $apr->param( $self->code.'_x' );
  $self->{'user_data'}{'hour'}  = $apr->param( $self->code.'_h' );
  return;
}

sub _render_widget_paper {
  my $self = shift;
  my $v = $self->value;
  return sprintf '<div class="bordered_short">%s</div>',
    strftime( $self->{'template_paper'},
              $v->{'second'},
              $v->{'minute'},
              $v->{'hour'},
              $v->{'day'},
              $v->{'month'}-1,
              $v->{'year'}-$YEAR_OFFSET );
}

sub _render_widget {
  my $self = shift;
  return $self->_render_widget_date.q( ).$self->_render_widget_time.$self->req_opt_string;
}

sub _render_widget_time {
  my $self = shift;
  my $code = encode_entities( $self->code );
  my $id   = $self->generate_id_string;
  my $v = $self->value;
  my $options = join q(), map {
    sprintf q(        <option value="%d"%s>%d</option>),
      $_, defined $v->{'hour'} && ($_ == ($v->{'hour'}||0) ) ? ' selected="selected"' : q(),
      $_;
  } ( 0 .. ($HOURS_IN_DAY-1) );

  my $return = sprintf '<select name="%s_h" id="%s">%s%s</select>',
     $code, $id, qq(\n        <option value="" >==</option>),
     $options;

  $options = join q(), map {
    sprintf q(        <option value="%d"%s>%02d</option>),
      $_, defined $v->{'minute'} && ($_ == ($v->{'minute'}||0) ) ? ' selected="selected"' : q(),
      $_;
  } ( 0 .. ($SIXTY-1) );
  $return .= sprintf ':<select name="%s_x" id="%s">%s%s</select>',
     $code, $id, qq(\n        <option value="" >==</option>),
     $options;
  if( $self->{'show_seconds'} ) {
    $options = join q(), map {
      sprintf q(        <option value="%d"%s>%02d</option>),
        $_, defined $v->{'second'} && ($_ == ($v->{'minute'}||0) ) ? ' selected="selected"' : q(),
        $_;
    } ( 0 .. ($SIXTY-1) );
    $return .= sprintf ':<select name="%s_s" id="%s">%s%s</select>',
      $code, $id, qq(\n        <option value="" >==</option>),
      $options;
  }
  return $return;
}

sub _render_widget_date {
  my $self = shift;
  my $code = encode_entities( $self->code );
  my $id   = $self->generate_id_string;

  my $v = $self->value;
  my $options = q();
  foreach ( 1 .. $DAYS_IN_MONTH ) {
    $options .= sprintf q(        <option value="%d"%s>%d</option>),
      $_,
      defined $v->{'day'} && ($_ == ($v->{'day'}||0) ) ? ' selected="selected"' : q(),
      $_;
  }
  my $return = sprintf '<select name="%s_d" id="%s">%s%s</select>',
     $code, $id, qq(\n        <option value="" >==</option>),
     $options;

  $options = q();
  foreach ( 1 .. $MONTHS_IN_YEAR ) {
    $options .= sprintf qq(\n        <option value="%d"%s>%s</option>),
      $_,
      defined $v->{'month'} && ($_ == ($v->{'month'}||0) ) ? ' selected="selected"' : q(),
      encode_entities(strftime( $self->three_letter ? '%b' : '%B' ,0,0,0,0,$_,0));
  }
  $return .= sprintf qq(\n      <select name="%s_m" id="%s_m">%s%s</select>),
    $code, $id, qq(\n        <option value="" >===</option>),
    $options;

  if( $self->{'use_range'} ) {
    $options = q();
    foreach ( $self->{'start_range'} .. $self->{'end_range'} ) {
      $options .= sprintf qq(\n        <option value="%d"%s>%s</option>),
        $_,
        defined $v->{'year'} && ($_ == ($v->{'year'}||0) ) ? ' selected="selected"' : q(),
        $_
    }
    $return .= sprintf qq(\n      <select name="%s_y" id="%s_y">%s%s</select>),
      $code, $id, qq(\n        <option value="" >====</option>),
      $options;

  } else {
    $return .= sprintf qq(\n      <input name="%s_y" id="%s_y" value="%s" class="short" />),
      $code, $id, encode_entities( defined $v->{'year'} ? $v->{'year'} : q() );
  }
  return $return;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_date_time' );
  return $self;
}

sub _render_readonly_date {
  my $self = shift;
  my $v = $self->value;
  return encode_entities(strftime( '%e %b %Y', 0,0,0,$v->{'day'}, $v->{'month'}-1, $v->{'year'} - $YEAR_OFFSET )) if defined $v->{'day'} && $v->{'day'} ne q();
  return encode_entities(strftime( '%b %Y',    0,0,0,0,           $v->{'month'}-1, $v->{'year'} - $YEAR_OFFSET )) if defined $v->{'month'} && $v->{'month'} ne q();
  return encode_entities(strftime( '%Y',       0,0,0,0,0,                          $v->{'year'} - $YEAR_OFFSET )) if defined $v->{'year'} && $v->{'year'} ne q();
  return q();
}

sub _render_readonly_time {
  my $self = shift;
  my $v = $self->value;
  return encode_entities(strftime( '%H:%M:%S', $v->{'second'}, $v->{'minute'}, $v->{'hour'}, 0, 0, 0 )) if defined $v->{'second'} ;
  return encode_entities(strftime( '%H:%M',    $v->{'second'}, $v->{'minute'}, 0, 0, 0, 0 ))            if defined $v->{'minute'};
  return encode_entities(strftime( '%H',       $v->{'second'}, 0, 0, 0, 0, 0 ))                         if defined $v->{'hour'};
  return q();
}

sub _render_readonly {
  my $self = shift;
  my $value = $self->_render_readonly_time.q( ).$self->_render_readonly_date;
  $value = q(--) if $value eq q( );
  return $value;
}
1;
