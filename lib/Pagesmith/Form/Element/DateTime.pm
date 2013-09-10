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

use Const::Fast qw(const);
const my $YEAR_OFFSET    => 1900;
const my $DAYS_IN_MONTH  => 31;
const my $MONTHS_IN_YEAR => 12;
const my $HOURS_IN_DAY   => 24;
const my $SIXTY          => 60;
const my $ONE_DAY        => $HOURS_IN_DAY * $SIXTY * $SIXTY;

use base qw( Pagesmith::Form::Element );

use POSIX qw(strftime);
use Date::Parse qw(strptime);
use List::MoreUtils qw(pairwise);

use HTML::Entities qw(encode_entities);

my @months = qw(January February March April May June July August September October November December);

sub init {
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
  foreach my $k ( qw(second minute hour day month year) ) {
    $return->{$k} = 0;
    foreach ( qw(user_data obj_data default) ) {
      next unless exists $self->{$_} && defined $self->{$_} && @{$self->{$_}} && exists $self->{$_}[0]{$k} && defined $self->{$_}[0]{$k};
      $return->{$k} = $self->{$_}[0]{$k};
      last;
    }
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

sub days_ago {
  my ( $self, $days ) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = - $days * $ONE_DAY + gmtime;
  $self->set_default_value( { 'second' => $sec,  'minute' => $min,  'hour' => $hour,
                        'day'    => $mday, 'month' => $mon+1, 'year' => $year+$YEAR_OFFSET } );
  return $self;
}

sub start_of_month {
  my $self = shift;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime;
  $self->set_default_value( { 'second' => 0,  'minute' => 0,  'hour' => 0,
                        'day'    => 1, 'month' => $mon+1, 'year' => $year+$YEAR_OFFSET } );
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
    $self->{'obj_data'} = [$value];
  } else {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = $self->munge_date_time_array( $value );
    $self->SUPER::set_obj_data([{
      'second' => $sec,  'minute' => $min,  'hour' => $hour,
      'day'    => $mday, 'month' => $mon+1, 'year' => $year+$YEAR_OFFSET }]);
  }
  return $self;
}

sub get_date_array {
  my($self,$date) = @_;
  my @time = strptime( $date );
  return unless @time;
  my @now  = gmtime;
  return pairwise { defined $a ? $a : $b } @time,@now;
}

sub update_from_apr {
  my( $self, $apr ) = @_;
  my $d = $apr->param( $self->code.'_d' );
  my $m = $apr->param( $self->code.'_m' );
  my $y = $apr->param( $self->code.'_y' );
  my $s = $apr->param( $self->code.'_s' );
  my $x = $apr->param( $self->code.'_x' );
  my $h = $apr->param( $self->code.'_h' );
  my $date = $apr->param( $self->code );
  if( defined $date ) {
    my @time = $self->get_date_array( $date );
    if( @time ) {
      my ($x_y,$x_m,$x_d,$x_h,$x_x,$x_s) = split m{:}mxs, strftime('%Y:%m:%d:%H:%M:%S',@time);
      $d ||= $x_d;
      $m ||= $x_m;
      $y ||= $x_y;
      $h ||= $x_h;
      $x ||= $x_x;
      $s ||= $x_s;
    }
  }

  $self->{'user_data'} = [{
    'day'     => defined $d ? $d : undef,
    'month'   => defined $m ? $m : undef,
    'year'    => defined $y ? $y : undef,
    'second'  => defined $s ? $s : undef,
    'minute'  => defined $x ? $x : undef,
    'hour'    => defined $h ? $h : undef,
  }];
  return;
}

sub render_widget_paper {
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

sub render_widget {
  my $self = shift;
  return $self->render_widget_date.q( ).$self->render_widget_time.$self->req_opt_string;
}

sub render_widget_time {
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

sub render_widget_date {
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
    $return .= sprintf qq(\n      <input name="%s_y" id="%s_y" value="%s" class="vshort" />),
      $code, $id, encode_entities( defined $v->{'year'} ? $v->{'year'} : q() );
  }
  return $return;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_date_time' );
  return $self;
}

sub render_readonly_date {
  my $self = shift;
  my $v = $self->value;
  return encode_entities(strftime( '%e %b %Y', 0,0,0,$v->{'day'}, $v->{'month'}-1, $v->{'year'} - $YEAR_OFFSET )) if defined $v->{'day'} && $v->{'day'} ne q();
  return encode_entities(strftime( '%b %Y',    0,0,0,0,           $v->{'month'}-1, $v->{'year'} - $YEAR_OFFSET )) if defined $v->{'month'} && $v->{'month'} ne q();
  return encode_entities(strftime( '%Y',       0,0,0,0,0,                          $v->{'year'} - $YEAR_OFFSET )) if defined $v->{'year'} && $v->{'year'} ne q();
  return q();
}

sub render_readonly_time {
  my $self = shift;
  my $v = $self->value;
  return encode_entities(strftime( '%H:%M:%S', $v->{'second'}, $v->{'minute'}, $v->{'hour'}, 0, 0, 0 )) if defined $v->{'second'} ;
  return encode_entities(strftime( '%H:%M',    $v->{'second'}, $v->{'minute'}, 0, 0, 0, 0 ))            if defined $v->{'minute'};
  return encode_entities(strftime( '%H',       $v->{'second'}, 0, 0, 0, 0, 0 ))                         if defined $v->{'hour'};
  return q();
}

sub render_widget_readonly {
  my $self = shift;
  my $value = $self->render_readonly_time.q( ).$self->render_readonly_date;
  $value = q(--) if $value eq q( );
  return $value;
}
1;
