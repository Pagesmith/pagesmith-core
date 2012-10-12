package Pagesmith::Form::Element::DropDown;

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

use base qw( Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

#--------------------------------------------------------------------
# Creates a form element for an option set, as either a select box
# or a set of radio buttons
# Takes an array of anonymous hashes, thus:
# my @values = (
#           {'name'=>'Option 1', 'value'=>'1'},
#           {'name'=>'Option 2', 'value'=>'2'},
#   );
# The 'name' element is displayed as a label or in the dropdown,
# whilst the 'value' element is passed as a form variable
#--------------------------------------------------------------------

sub _init {
  my( $self, $element_data ) = @_;

  $element_data ||= {};

  if( exists $element_data->{'print_as'} &&
      $element_data->{'print_as'} eq 'box' ) {
    $self->set_print_as_box;
  } else {
    $self->set_print_as_list;
  }
  return $self
    ->set_firstline(        $element_data->{'firstline'}       )
    ->set_firstline_value(  $element_data->{'firstline_value'} )
    ->set_values(           $element_data->{'values'}          );
}

sub set_firstline {
  my( $self, $value ) = @_;
  $self->{'_firstline'} = $value;
  return $self;
}
sub firstline {
  my $self = shift;
  return $self->{'_firstline'};
}
sub set_firstline_value {
  my( $self, $value ) = @_;
  $self->{'_firstline_value'} = $value||undef;
  return $self;
}
sub firstline_value {
  my $self = shift;
  return q() unless defined $self->{'_firstline_value'};
  return $self->{'_firstline_value'};
}

## no critic (BuiltinHomonyms)
sub set_values {
  my( $self, $values ) = @_;
  $self->{'_values'} = $values;
  return $self;
}

sub add_values {
  my( $self, @values ) = @_;
  push @{$self->{'_values'}}, @values;
  return $self;
}

sub values {
  my $self = shift;
  return map { { 'value' => $_, 'name' => $self->{'_values'}{$_} } } sort keys %{$self->{'_values'}}
    if ref $self->{'_values'} eq 'HASH';
  return @{ $self->{'_values'} || [] };
}
## use critic (BuiltinHomonyms)

sub print_as {
  my $self = shift;
  return $self->{'_print_as'};
}

sub element_class {
  my $self = shift;
  $self->add_class( '_dropdown' );
  return;
}

sub set_print_as_box {
  my $self = shift;
  $self->{'_print_as'} = 'box';
  return $self;
}

sub set_print_as_list {
  my $self = shift;
  $self->{'_print_as'} = 'list';
  return $self;
}

sub _validate {
  my $self = shift;
  return $self->render_as eq 'select';
}

sub _render_widget_paper {
  my $self = shift;
  if( $self->print_as eq 'box' ) {
    my $class = $self->_class =~ m{short}mxs ? 'bordered_short' : 'bordered';
    return sprintf '<div class="%s">%s</div>',
      $class,
      encode_entities( $self->value )||'&nbsp;'
    ;
  }
  my $options = q();
  my $current_group = q();
  my $html = q();
  foreach my $V ( $self->values ) {
    $V = {'value'=>$V,'name'=>$V} unless ref $V;
    if( exists $V->{'group'} && $V->{'group'} ne $current_group ) {
      if( $current_group ) {
        $options.="\n       </ul></li>";
      }
      if( $V->{'group'}) {
        $options.= sprintf qq(\n       <li>%s<ul>), encode_entities( $V->{'group'} );
      }
      $current_group = $V->{'group'};
    }
    my $extra = $self->value eq $V->{'value'} ? 'X' : '&nbsp;&nbsp;';
    my $value = $V->{'name'} || $V->{'value'};
    $options .= sprintf qq(\n        <li><span>%s</span>%s</li>),
      $extra, $self->raw ? $value : encode_entities( $value )
    ;
  }
  if( $current_group ) {
    $options.="\n       </ul></li>";
  }

  return qq(<ul class="boxes">$options</ul>);
}

sub _render_readonly {
  my $self = shift;
  my $value = $self->value;
  my ($text)  = map { ( ref $_ ? ($_->{'value'} eq $value ? ($_->{'name'}) : ()) : ( $_ eq $value ? ($_) : () ) ) } $self->values;
  $text = q(--) unless defined $text;
  return $self->raw ? $text : encode_entities( $text );
}

sub _render_widget {
  my $self = shift;
  my $options = q();
  my $current_group = q();
  if( $self->firstline ) {
    $options .= sprintf qq(\n         <option value="%s">%s</option>), encode_entities( $self->firstline_value ), encode_entities( $self->firstline );
  }
  my $optcount = 0;
  foreach my $V ( $self->values ) {
    $V = {'value'=>$V,'name'=>$V} unless ref $V;
    if( exists $V->{'group'} && $V->{'group'} ne $current_group ) {
      if( $current_group ) {
        $options.="\n       </optgroup>";
      }
      if( $V->{'group'}) {
        my $group_class = q();
        $group_class = sprintf ' class="%s"', encode_entities( $V->{'group_class'} ) if exists $V->{'group_class'};
        $options.= sprintf qq(\n       <optgroup label="%s"%s>), encode_entities( $V->{'group'} ), $group_class;
      }
      $current_group = $V->{'group'};
    }
    my $extra = $self->value eq $V->{'value'} ? ' selected="selected"' : q();
    my $value = $V->{'name'} || $V->{'value'};
    $options .= sprintf qq(\n        <option value="%s"%s>%s</option>),
      encode_entities( $V->{'value'} ), $extra, $self->raw ? $self->strip_html( $value ) : encode_entities( $self->strip_html( $value ) );
    $optcount++;
  }
  if( $current_group ) { $options.="\n       </optgroup>"; }

  return sprintf qq(<select name="%s" id="%s" class="%s">%s\n      </select>%s),
    encode_entities( $self->code ),
    $self->generate_id_string,
    $self->generate_class_string,
    $options,
    $self->req_opt_string
    ;

}

1;
