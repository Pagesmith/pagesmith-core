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
const my $CENTURY        => 100;
const my $FOUR           => 4;
const my $QUADCENTURY    => 400;
const my $FEB            => 2;
const my $MAX_MONTH      => 31;
const my %MONTH_MAX      => qw(1 31 2 29 3 31 4 30 5 31 6 30 7 31 8 31 9 30 10 31 11 30 12 31);

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
  my( $self, $start, $end, $options ) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime;
  $options ||= {};
  my $this_year = $year+$YEAR_OFFSET;
  $self->{'use_range'} = 1;
  $self->{'start_range'} = defined $start ? ( exists $options->{'rel_start'} ? $this_year+$start : $start ) : $this_year;
  $self->{'end_range'}   = defined $end   ? ( exists $options->{'rel_end'  } ? $this_year+$end   : $end   ) : $this_year;
  return $self;
}

## no critic (AmbiguousNames)
sub second {
  my $self = shift;
  return $self->get_value('second')->{'second'};
}
## use critic

sub minute {
  my $self = shift;
  return $self->get_value('minute')->{'minute'};
}

sub hour {
  my $self = shift;
  return $self->get_value('hour')->{'hour'};
}

sub day {
  my $self = shift;
  return $self->get_value('day')->{'day'};
}

sub month {
  my $self = shift;
  return $self->get_value('month')->{'month'};
}

sub year {
  my $self = shift;
  return $self->get_value('year')->{'year'};
}

sub value {
  my $self = shift;
  return $self->get_value( qw(second minute hour day month year) );
}

sub get_value {
  my( $self, @parts ) = @_;
  my $return = {};
  foreach my $k ( @parts ) {
    $return->{$k} = 0;
    foreach ( qw(user_data obj_data default) ) {
      next unless exists  $self->{$_} &&
                  defined $self->{$_} &&
                        @{$self->{$_}} &&
                  exists $self->{$_}[0]{$k} &&
                  defined $self->{$_}[0]{$k};
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
  if( 'ARRAY' eq ref $value ) {
    return unless @{$value};
    $value = $value->[0];
  } else {
    return unless defined $value;
  }
  if( 'HASH' eq ref $value ) {
    $self->{'obj_data'} = [$value];
  } else {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = $self->munge_date_time_array( $value );
    $mon  ++              if defined $mon;
    $year += $YEAR_OFFSET if defined $year;
    $self->SUPER::set_obj_data([{
      'second' => $sec,  'minute' => $min,  'hour' => $hour,
      'day'    => $mday, 'month' => $mon, 'year' => $year }]);
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

sub limit_day {
  my ($self,$d,$m,$y) = @_;
  return $d if ! defined $d || $d eq q();

  $d = 1              if $d < 1;
  $d = $MAX_MONTH     if $d > $MAX_MONTH;

  return $d unless defined $m && exists $MONTH_MAX{$m};

  $d = $MONTH_MAX{$m} if $d>$MONTH_MAX{$m}; ## Limit to days of month;
  return $d   unless $y; ## No year defined so can't limit!

  return $d   unless $m == $FEB;           ## Not feb so we know w have it right!
  return $d   unless $d == $MONTH_MAX{$m}; ## Not the 29th!
  return $d   unless $y % $QUADCENTURY;    ## Divisible by 400 so leap year!
  return $d-1 unless $y % $CENTURY;        ## Divisible by 100 so not leap year
  return $d   unless $y % $FOUR;           ## Divisible by 4 so leap year!
  return $d-1;                             ## Not leap year!
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
  $d = $self->limit_day( $d,$m,$y );

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
