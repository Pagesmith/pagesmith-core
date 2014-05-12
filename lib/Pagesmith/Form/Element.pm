package Pagesmith::Form::Element;

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

use base qw(Pagesmith::Form::Root);

use Carp;
use HTML::Entities qw(encode_entities decode_entities);
use List::MoreUtils qw(any);
use English qw(-no_match_vars $PID);
use Pagesmith::ConfigHash qw(get_config);
use Text::Wrap qw(wrap $columns $huge);
use Encode qw(decode_utf8 encode_utf8);
use Const::Fast qw(const);

const my $LONG_LINE_LENGTH  => 72;
const my $SHORT_LINE_LENGTH => 40;
const my $CAPTION_WIDTH     => 26;

sub new {
  my ( $class, $section, $element_data ) = @_;

  my $id   = $element_data->{'id'};
  my $code = $element_data->{'code'} || $element_data->{'id'};
  ( my $t_code = $code ) =~ s{_}{ }mxgs;
  my $self = {
    'object'         => $section->object,
    'config'         => $section->form_config,
    'r'              => $section->r,
    'raw'            => exists $element_data->{'raw'} && $element_data->{'raw'} eq 'yes' ? 1 : 0,
    'id'             => $element_data->{'id'} || $section->form_config->next_id,
    'alias'          => $element_data->{'alias'} || $code,
    'classes'        => { map { $_=>1 } $section->form_config->classes('element') },
    'layouts'        => { map { $_=>1 } $section->form_config->classes('layout') },
    'caption'        => exists $element_data->{'caption'} ? $element_data->{'caption'} : ucfirst $t_code,
## Values are always array refs now to allow for multiple valued entries
    'default'        => exists $element_data->{'default'}
                      ? ('ARRAY' eq ref $element_data->{'default'} ? $element_data->{'default'} :  [$element_data->{'default'}] )
                      : [],

    'info'           => exists $element_data->{'info'}    ? $element_data->{'info'} : q(),
    'notes'          => exists $element_data->{'notes'}   ? $element_data->{'notes'} : q(),
    'required'       => (exists $element_data->{'required'} && $element_data->{'required'} eq 'no') ? 'no' : 'yes',
    'hidden_caption' => exists $element_data->{'hidden_caption'} ? $element_data->{'hidden_caption'} : q(),
    'options'        => $element_data,
    'readonly'       => exists $element_data->{'readonly'} ? $element_data->{'readonly'} : 0,
    'invalid'        => 0,
    'view_in_table'  => 0,
    'enabled'        => 1,
    'logic_type'     => 'any', ## none (0), any (>0), all (N), not_all (<N), 'at_least_\d', 'at_most_\d',
    'logic'          => [],
    'multiple'       => exists $element_data->{'multiple'} ? $element_data->{'multiple'} : 0,
  };

  $self->{ 'code' } = $element_data->{ 'code' }||$self->{ 'id' };

  bless $self, $class;
  $self->init( $element_data );
  $self->element_class;

  if( exists $element_data->{'class'} ) {
    $self->add_class( $element_data->{'class'} );
  }

  if( exists $element_data->{'layout'} ) {
    $self->add_layout( $element_data->{'layout'} );
  }
  return $self;
}

sub init {
  my $self = shift;
  return $self;
}

sub r {
  my $self = shift;
  return $self->{'r'};
}

sub set_user_data {
  my( $self, @values ) = @_;
  if( 'ARRAY' eq ref $values[0] ) {
    $self->{'user_data'} = $values[0];
  } else {
    my @v = grep { defined $_ } @values;
    $self->{'user_data'} = @v ? \@v : undef;
  }
  return $self;
}

sub user_data {
  my $self = shift;
  return $self->{'user_data'};
}

sub set_obj_data {
  my( $self, @values ) = @_;
  if( 'ARRAY' eq ref $values[0] ) {
    $self->{'obj_data'} = $values[0];
  } else {
    my @v = grep { defined $_ } @values;
    $self->{'obj_data'} = @v ? \@v : undef;
  }
  return $self;
}

sub obj_data {
  my $self = shift;
  return $self->{'obj_data'};
}

sub hide_readonly {
  my $self = shift;
  $self->{'hide_readonly'} = 1;
  return $self;
}

sub hidden_readonly {
  my $self = shift;
  return $self->{'hide_readonly'};
}

sub set_view_in_table {
  my $self = shift;
  $self->{'view_in_table'} = 1;
  return $self;
}

sub view_in_table {
  my $self = shift;
  return $self->{'view_in_table'};
}

sub set_raw {
  my $self = shift;
  $self->{'raw'} = 1;
  return $self;
}

sub set_raw_caption {
  my $self = shift;
  $self->{'raw_caption'} = 1;
  return $self;
}

sub raw {
  my $self = shift;
  return $self->{'raw'} || 0;
}

sub raw_caption {
  my $self = shift;
  return $self->{'raw_caption'} || 0;
}

sub clear_raw_caption {
  my $self = shift;
  $self->{'raw_caption'} = 0;
  return $self;
}

sub clear_raw {
  my $self = shift;
  $self->{'raw'} = 0;
  return $self;
}

sub multiple_button {
  my $self = shift;
  return q();
}

sub multiple_markup {
  my $self = shift;
  return q() unless $self->multiple;
  return join q(), map {
    sprintf '<span class="close_box">%s<input type="hidden" value="%s" name="%s" /></span>',
      encode_entities($_), encode_entities($_), encode_entities( $self->code );
  } $self->multi_values;
}

sub set_multiple {
  my $self = shift;
  $self->{'multiple'} = 1;
  return $self;
}


sub clear_multiple {
  my $self = shift;
  $self->{'multiple'} = 0;
  return $self;
}

sub multiple {
  my $self = shift;
  return $self->{'multiple'}||0;
}

##-- Set and read "readonly" status of an element

sub set_readonly {
  my $self = shift;
  $self->{'readonly'} = 1;
  return $self;
}

sub set_editable {
  my $self = shift;
  $self->{'readonly'} = 0;
  return $self;
}

sub is_readonly {
  my $self = shift;
  return $self->{'readonly'};
}

sub is_input {
  my $self = shift;
  return ! $self->is_readonly;
}

##-- Get/Set/clear invalid status

sub set_valid_state {
  my( $self, $value ) = @_;
  $value = 1 unless defined $value;
  $self->{'invalid'} = ! $value;
  return $self;
}

sub set_invalid {
  my $self = shift;
  $self->{'invalid'} = 1;
  return $self;
}

sub set_valid {
  my $self = shift;
  $self->{'invalid'} = 0;
  return $self;
}

sub is_invalid {
#@return (boolean) True if the form element is valid
  my $self = shift;
  return $self->{'invalid'};
}

sub is_valid {
#@return (boolean) True if the form element is valid
  my $self = shift;
  return ! $self->{'invalid'};
}

##-- Get/Set/clear "do not store" status

sub set_do_not_store {
  my $self = shift;
  $self->{'do_not_store'} = 1;
  return $self;
}

sub clear_do_not_store {
  my $self = shift;
  $self->{'do_not_store'} = 1;
  return $self;
}

sub do_not_store {
## By default all elements have values stored for them....
  my $self = shift;
  return $self->{'do_not_store'}||0;
}

##-- Check to see if value is "empty"
sub is_empty {
  my $self = shift;
  return 1 unless defined $self->value;
  return $self->value eq q();
}


sub logic_link {
  my $self = shift;
  $self->{'logic_linked'} = 'yes';
  return $self;
}

sub logic_linked {
  my $self = shift;
  return $self->{'logic_linked'} || 'no';
}

sub form_config {
  my $self = shift;
  return $self->{'config'};
}
sub set_object {
  my( $self, $value ) = @_;
  $self->{'object'} = $value;
  return $self;
}

sub set_matches {
  my( $self, $other_code ) = @_;
  $self->{'matches'} = $other_code;
  return $self;
}

sub clear_matches {
  my $self = shift;
  $self->{'matches'} = undef;
  return $self;
}

sub matches {
  my $self = shift;
  return $self->{'matches'};
}

sub object {
  my $self = shift;
  return $self->{'object'};
}

##-- Set/get standard values of element

sub set_id {
  my( $self, $value ) = @_;
  $self->{'id'} = $value;
  return $self;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub set_code {
  my( $self, $value ) = @_;
  $self->{'code'} = $value;
  return $self;
}

sub code {
  my $self = shift;
  return $self->{'code'};
}

sub set_alias {
  my( $self, $value ) = @_;
  $self->{'alias'} = $value;
  return $self;
}

sub reset_alias {
  my $self = shift;
  $self->{'alias'} = $self->{'code'};
  return $self;
}

sub alias {
  my $self = shift;
  return $self->{'alias'};
}

sub set_info {
  my( $self, $value ) = @_;
  $self->{'info'} = $value;
  return $self;
}

sub info {
  my $self = shift;
  return $self->{'info'};
}

sub set_notes {
  my( $self, $value ) = @_;
  $self->{'notes'} = $value;
  return $self;
}

sub notes {
  my $self = shift;
  return $self->{'notes'};
}

sub set_caption {
  my( $self, $value ) = @_;
  $self->{'caption'} = $value;
  return $self;
}

sub caption {
  my $self = shift;
  return $self->{'caption'};
}

sub set_default_value {
  my( $self, @values ) = @_;
  if( 'ARRAY' eq ref $values[0] ) {
    $self->{'default'} = $values[0];
  } else {
    $self->{'default'} = [ grep { defined $_ } @values ];
  }
  return $self;
}


sub default_value {
  my $self = shift;
  return $self->{'default'};
}

sub set_hidden_caption {
  my( $self, $value ) = @_;
  $self->{'hidden_caption'} = $value;
  return $self;
}

sub hidden_caption {
  my $self = shift;
  return $self->{'hidden_caption'};
}

sub set_optional_string {
  my( $self, $value ) = @_;
  $self->{'optional_string'} = $value;
  return $self;
}

sub set_required_string {
  my( $self, $value ) = @_;
  $self->{'required_string'} = $value;
  return $self;
}

sub req_opt_string {
  my $self = shift;
  my $s = $self->is_required ? $self->required_string : $self->optional_string;
  return $s ne q() ? " $s" : q();
}

sub optional_string {
  my $self = shift;
  return $self->{'options'}{'optional_string'}
    ? $self->{'options'}{'optional_string'}
    : $self->form_config->option('optional_string');
}

sub required_string {
  my $self = shift;
  return $self->{'options'}{'required_string'}
    ? $self->{'options'}{'required_string'}
    : $self->form_config->option('required_string');
}

sub option {
  my( $self,$key ) = @_;
  return unless exists $self->{'options'}{$key};
  return $self->{'options'}{$key};
}

sub validate {
#@return (boolean) True if the element must be validated;
  my $self = shift;
  return $self;
}

sub tidy_up {
  my( $self, $string, $flag ) = @_;
  return $self->trim( $flag eq 'utf-8' ? decode_utf8($string) : $string );
}

sub update_from_apr {
## update the element from the
  my( $self, $apr, $flag ) = @_;
  my @v = $apr->param( $self->code ); ## We need to collect multiple values;
  if( $self->{'multiple'} ) {
    $self->{'user_data'} = [ grep { $_ ne q() } map { $self->tidy_up( $_, $flag ) } @v ];
  } elsif( @v ) {
    $self->{'user_data'} = [ $self->tidy_up( $v[0], $flag ) ];
  } else {
    $self->{'user_data'} = undef;
  }
  return;
}

sub multi_values {
  my $self = shift;
  return @{$self->user_data}          if defined $self->user_data;
  return @{$self->obj_data}           if defined $self->obj_data;
  return @{$self->default_value||[]};
}

sub value {
  my $self = shift;
  my @values = $self->multi_values;
  return $values[0] if @values;
  return q();
}

sub scalar_value {
  my $self = shift;
  return $self->value;
}

#= Class manipulation functions...

sub layouts {

#@param (self)
#@return (string+) list of classes
## Return the list of classes associated with the form!
  my $self = shift;
  my @classes = sort keys %{ $self->{'layouts'} };
  return @classes;
}

sub remove_layout {
  my ( $self, @classes ) = @_;
  @classes = @{$classes[0]} if @classes == 1 && ref $classes[0] eq 'ARRAY';
  delete $self->{'layouts'}{$_} foreach @classes;
  return $self;
}

sub set_layout {
  my( $self, @classes ) = @_;
  @classes = @{$classes[0]} if @classes == 1 && ref $classes[0] eq 'ARRAY';
  $self->{'layouts'} = { map { ($_=>1) } @classes };
  return $self;
}
sub add_layout {

#@param (self)
#@param (string) $class CSS class to add to form
## Adds class to form - usually these define the way the form operates:
## 'check' - perform rudimentary validation on elements as form is displayed,
## when form fields change and when the form is submitted; 'confirm' -
## include a gray box yes/no when "submit" has been hit!
## 'partial' - allow the form to be "stored" without being completed
## this needs means that errors will be noted - but the form will be
## submitted (grey box yes/no when "submit" hit rather than alert).

  my ( $self, @classes ) = @_;
  @classes = @{$classes[0]} if @classes == 1 && ref $classes[0] eq 'ARRAY';
  $self->{'layouts'}{$_} = 1 foreach @classes;
  return $self;
}

sub set_class {
  my( $self, @classes ) = @_;
  @classes = @{$classes[0]} if @classes == 1 && ref $classes[0] eq 'ARRAY';
  $self->{'classes'} = { map { ($_=>1) } @classes };
  return $self;
}

sub classes {

#@param (self)
#@return (string+) list of classes
## Return the list of classes associated with the form!
  my $self = shift;
  my @classes = sort keys %{ $self->{'classes'} };
  return @classes;
}

sub remove_class {
  my ( $self, @classes ) = @_;
  @classes = @{$classes[0]} if @classes == 1 && ref $classes[0] eq 'ARRAY';
  delete $self->{'classes'}{$_} foreach @classes;
  return $self;
}

sub add_class {

#@param (self)
#@param (string) $class CSS class to add to form
## Adds class to form - usually these define the way the form operates:
## 'check' - perform rudimentary validation on elements as form is displayed,
## when form fields change and when the form is submitted; 'confirm' -
## include a gray box yes/no when "submit" has been hit!
## 'partial' - allow the form to be "stored" without being completed
## this needs means that errors will be noted - but the form will be
## submitted (grey box yes/no when "submit" hit rather than alert).

  my ( $self, @classes ) = @_;
  @classes = @{$classes[0]} if @classes == 1 && ref $classes[0] eq 'ARRAY';
  $self->{'classes'}{$_} = 1 foreach @classes;
  return $self;
}

sub layout_class_string {
  my $self = shift;
  my $q = join q( ), $self->layouts;
  return $q ? sprintf ' class="%s"', encode_entities( $q ) : q();
}

sub generate_class_string {
  my $self = shift;
  $self->add_class( $self->is_required ? 'required' : 'optional' );
  $self->add_class( 'multiple' ) if $self->multiple;
  return join q( ), $self->classes;
}

sub generate_label_string {
  my $self = shift;
  my $label_string  = sprintf '<label for="%s">', $self->generate_id_string;
     $label_string .= sprintf '<span class="hidden">%s</span>', $self->hidden_caption if $self->hidden_caption;
     $label_string .= sprintf '%s', $self->raw_caption ? $self->caption : encode_entities( $self->caption ) if $self->caption;
     $label_string .= q(</label>);

  return $label_string;
}

sub generate_id_string {
  my $self = shift;
  return $self->form_config->form_id.'_'.$self->id;
}

sub has_file {
  return 0;
}

sub has_file_no_ignored {
  return 0;
}

sub render {
  my( $self, $form ) = @_;
  return q() if $self->has_logic && ! $form->evaluate_logic( $self );
  return $self->render_readonly if $self->is_readonly;
  my $layout_string = $self->layout_class_string;

  return sprintf "\n      <dt%s>\n        %s\n      </dt>\n      <dd%s>\n        %s%s%s%s\n      </dd>",
    $layout_string,
    $self->generate_label_string,
    $layout_string,
    $self->info  ? qq(\n        <div class="clear">\n          ) . $self->info  . "\n        </div>" : q(),
    $self->render_widget,
    $self->extra_information,
    $self->notes ? qq(\n        <div class="clear">\n          ) . $self->notes . "\n        </div>" : q(),
  ;
}

sub extra_information {
  return q();
}

sub render_paper {
  my( $self, $form ) = @_;
  return if $self->has_logic && ! $form->evaluate_logic( $self );
  my $class_string = $self->layout_class_string;
  return sprintf "      <dt%s>\n        %s\n      </dt>\n      <dd%s>\n        %s%s%s%s\n      </dd>",
    $class_string,
    ( $self->raw_caption ? $self->caption : encode_entities( $self->caption ) ) || '&nbsp;',
    $class_string,
    $self->info ? qq(\n    <div class="clear">) . $self->info . '</div>' : q(),
    $self->render_widget_paper(),
    $self->notes ? qq(\n    <div class="clear">) . $self->notes . '</div>' : q(),
  ;
}

sub render_readonly {
  my( $self, $form ) = @_;
  return q() if $self->has_logic && ! $form->evaluate_logic( $self );
  return q() if $self->hidden_readonly;
  my $layout_string = $self->layout_class_string;
  return sprintf "\n      <dt%s>\n        %s\n      </dt>\n      <dd%s>\n        %s\n      </dd>",
    $layout_string,
    ( $self->raw_caption ? $self->caption : encode_entities( $self->caption ) ) || '&nbsp;',
    $layout_string,
    $self->render_widget_readonly()
  ;
}

sub render_widget_paper {
  my $self = shift;
  return $self->render_widget;
}

sub render_value_if_raw {
  my( $self,$val ) = @_;
  my $rendered_val = $self->render_value( $val );
  return $rendered_val      if $self->raw;
  my $eval_tmp = eval { encode_entities( $rendered_val ) };
  return $eval_tmp if $eval_tmp;
  $rendered_val =~ s{&}{&amp;}mxsg;
  $rendered_val =~ s{<}{&lt;}mxsg;
  $rendered_val =~ s{>}{&gt;}mxsg;
  return $rendered_val;
}

sub render_widget_readonly {
  my $self = shift;
  my $val = q();
  # Multi-valued entries
  if( $self->multiple &&
      $self->multi_values   &&
      $self->multi_values > 1 ) {
    $val = sprintf '<ul><li>%s</li></ul>', join q(</li><li>),
      map { $self->render_value_if_raw( $_ ) } $self->multi_values;
  } elsif( $self->multi_values ) {
    $val = $self->render_value_if_raw( $self->value );
  }
  $val = '&nbsp;' if $val =~ m{\A\s*\Z}mxs;
  return $val;
}

sub twrap {
## Wrapper around Text::Wrap::wrap to put an appropriate wrapped entry for sending in a plain
## text email...
  my($self,$string,$pad, $sep, $cols ) = @_;
  my $sub_tab = q( ) x $pad .$sep;
  $columns  = $cols;
  $huge     = 'overflow';
  return join "\n$sub_tab", split m{\n}mxs, wrap( q(), q(), $string||q(-) );
}

sub render_email {
  my( $self, $form ) = @_;
  my $value = $self->render_widget_readonly;
  $value = q(--) if $value eq '&nbsp;';
  $value =~ s{<[^>]+>}{}mxgs;
  $value = decode_entities( $value );
  return $self->_render_email( $value );
}

sub _render_email {
  my( $self, $value ) = @_;
  (my $caption = $self->caption) =~ s{<[^>]+>}{}mxgs;
  $caption = decode_entities( $caption );
  return sprintf "\n%s\n-------------------------------------\n%s\n\n",
    $self->twrap( $caption, 0, q(), $LONG_LINE_LENGTH ), $self->twrap( $value, 0, q(), $LONG_LINE_LENGTH )
    if $self->value =~ m{[\r\n]}mxs || length $value >= 2 * $SHORT_LINE_LENGTH;
  return sprintf "%s\n%${CAPTION_WIDTH}s : %s\n",
    $self->twrap( $caption, 0, q(), $LONG_LINE_LENGTH ), q(), $self->twrap( $value, $CAPTION_WIDTH, q( : ), $SHORT_LINE_LENGTH )
    if length $caption > $CAPTION_WIDTH;
  return sprintf "%${CAPTION_WIDTH}s : %s\n",
    $caption, $self->twrap( $value, $CAPTION_WIDTH, q( : ), $SHORT_LINE_LENGTH );
}

sub element_class {
  my $self = shift;
  return $self;
}

sub tmp_filename {
## Return a temporary file name - that exists on real disk! - we may later delete
## this!
  my ( $self, $xtn ) = @_;
  return get_config('RealTmp') . $PID . q(.) . time() . ( defined $xtn ? qq(.$xtn) : q() );
}


1;
