package Pagesmith::Form::Element::Text;

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
const my $DEFAULT_ROWS => 10;
const my $DEFAULT_COLS => 60;
const my $DEFAULT_UNIT => 60;

my $units = { map { $_ => 1 } qw(ids characters words) };
use base qw( Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

### Textarea element;

sub init {
  my( $self, $element_data ) = @_;
  if( exists $element_data->{'max_length'} ) {
    $self->set_max_length( $element_data->{'max_length'}||0,
      exists $element_data->{'max_units'} && exists $units->{$element_data->{'max_units'}} ?
        $element_data->{'max_units'} : $DEFAULT_UNIT );
  }
  $self->{'rows'}       = ( $element_data->{'rows'}       || $DEFAULT_ROWS );
  $self->{'cols'}       = ( $element_data->{'cols'}       || $DEFAULT_COLS );
  return;
}

sub set_max_length {
  my( $self, $value, $unit ) = @_;
  $self->{'max_length'} = $value;
  $self->{'max_units' } = exists $units->{ $unit } ? $unit : 'characters';
  if( $value > 0 ) {
    $self->add_class( '_max_len' );
  } else {
    $self->remove_class( '_max_len' );
  }
  return $self;
}

sub max_length {
  my $self = shift;
  return $self->{'max_length'};
}

sub set_rows {
  my( $self, $value ) = @_;
  $self->{'rows'} = $value;
  return $self;
}

sub set_cols {
  my( $self, $value ) = @_;
  $self->{'cols'} = $value;
  return $self;
}

sub rows {
  my $self = shift;
  return $self->{'rows'};
}

sub cols {
  my $self = shift;
  return $self->{'cols'};
}

sub count {
  my $self = shift;
  if( $self->{'max_units'} eq 'words' ) {
    my @words = $self->value =~ m{\b(\w+-\w+|\w+'\w\w?|\w+)\b}mxgs ;
    return scalar @words;
  }
  return length $self->value;
}

sub extra_information {
  my $self = shift;
  return q() unless $self->{'max_length'};
  return sprintf '<div class="max_len">Length: <span class="count">%d</span>/<span class="max">%d</span> <span class="units">%s</span></div>',
    $self->count( $self->{'max_units'} ),
    $self->{'max_length'}, $self->{'max_units'};

}

sub set_is_list {
  my $self = shift;
  $self->{'is_list'} = 1;
  return $self;
}

sub set_is_not_list {
  my $self = shift;
  $self->{'is_list'} = 0;
  return $self;
}

sub is_list {
  my $self = shift;
  return $self->{'is_list'};
}


sub render_widget {
  my $self = shift;
  my $id_string = $self->generate_id_string;

  return sprintf '<textarea name="%s" id="%s" rows="%d" cols="%d" class="%s">%s</textarea>%s',
    encode_entities( $self->code ),
    $id_string,
    $self->rows,
    $self->cols,
    $self->generate_class_string,
    encode_entities( $self->value ),
    $self->req_opt_string;
}

sub render_widget_readonly {
  my $self = shift;
  return '&nbsp' unless $self->value;
  return sprintf '<ul>%s</ul>', join q(), map { sprintf '<li>%s</li>', encode_entities( $_ )  } split m{\n+}mxs, $self->value if $self->is_list;
  return join q(), map { sprintf '<p>%s</p>', encode_entities( $_ ) } split m{\n\s*\n}mxs, $self->value;
}

sub render_widget_paper {
  my $self = shift;

  return sprintf '<div class="bordered_tall">%s</div>',
    $self->render_widget_readonly( $self->value );
}

sub element_class {
  my $self = shift;
  $self->add_class( '_text' );
  return;
}

1;
