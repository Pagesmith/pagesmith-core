package Pagesmith::Form::ElementTmp::DropDownAndString;

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
  my($self, $params ) = @_;

  $self->{'render_as'}    = $params->{'select'} ? 'select' : 'radiobutton';
  $self->{'string_value'} = $params->{'string_value'};
  $self->{'string_name'}  = $params->{'string_name'};
  $self->{'string_label'} = $params->{'string_label'};
  return $self;
}

sub _validate {
  my $self = shift;
  return $self->render_as eq 'select';
}

sub string_name {
  my $self = shift;
  return $self->{'string_name'};
}
sub string_value {
  my $self = shift;
  return $self->{'string_value'};
}

sub string_label {
  my $self = shift;
  return $self->{'string_label'};
}

sub render {
  my $self = shift;
  if( $self->render_as eq 'select' ) {
    my $options = q();
    foreach my $V ( @{$self->values} ) {
      my %v_hash = %{$V};
      my $selected;
      if ($self->value && ref($self->value) eq 'ARRAY') {
        foreach my $v (@{$self->value}) {
          if ($v eq $v_hash{'value'}) {
            $selected = 1;
            last;
          }
        }
      }
      else {
        $selected = 1 if $self->value eq $v_hash{'value'};
      }

      $options .= sprintf qq(<option value="%s"%s>%s</option>\n),
        $v_hash{'value'}, $selected ? ' selected="selected"' : q(), $v_hash{'name'}
      ;
    }
    return sprintf qq(<tr><td>%s<select name="%s" id="%s">\n%s</select><td>\n      <input type="text" name="%s" value="%s" id="%s" class="%s" />%s\n    %s</td></tr>),
      $self->introduction,
      encode_entities( $self->name ),
      encode_entities( $self->id ),
      $self->type, $self->is_required ? 1:0,
      $options,
      encode_entities( $self->string_name ),
      encode_entities( $self->string_value ),
      encode_entities( $self->id.'_string' ),
      $self->style, $self->is_required?1:0, $self->is_required ? 1 : 0,
      $self->req_opt_string,
      $self->notes,
    ;
  } else {
    my $output = '<tr><td></td><td>';
    my $K = 0;
    foreach my $V ( @{$self->values} ) {
      $output .= sprintf qq(<input id="%s_%d" class="radio" type="radio" name="%s" value="%s" %s /><label for="%s_%d">%s</label>\n),
        encode_entities($self->id),
        $K,
        encode_entities($self->name),
        encode_entities($V->{'value'}),
        $self->value eq $V->{'value'} ? ' checked="checked"' : q(),
        encode_entities($self->id),
        $K,
        encode_entities($V->{'name'}),
      ;
      $K++;
    }
    return $self->introduction.$output.
      sprintf
        qq(</td><td><input type="text" name="%s" value="%s" id="%s" class="%s" />%s\n        %s</td></tr>),
        encode_entities( $self->string_name ),
        encode_entities( $self->string_value ),
        encode_entities( $self->id.'_string' ),
        $self->style, $self->is_required ? 1 : 0, $self->is_required ? 1 : 0,
        $self->req_opt_string,
        $self->notes,
      ;
  }
  return;
}

sub validate {
  return 1;
}

1;
