package Pagesmith::Form;

## Form handling package
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

use base qw(Pagesmith::Support);

use Carp qw(carp);
use HTML::Entities qw(encode_entities);
use URI::Escape qw(uri_escape_utf8);
use List::MoreUtils qw(any firstidx);

## Form child objects;

use Pagesmith::Form::Stage;
use Pagesmith::Form::Stage::Confirmation;
use Pagesmith::Form::Stage::Final;
use Pagesmith::Form::Stage::Redirect;
use Pagesmith::Form::Stage::Error;
use Pagesmith::Form::Config;
use Pagesmith::Form::Message;
use Pagesmith::Form::SubmitButton;
use Pagesmith::Form::ResetButton;
use Pagesmith::Adaptor;

use Pagesmith::Session::User;
use Pagesmith::Cache;
use Pagesmith::Core       qw(safe_md5);
use Pagesmith::ConfigHash qw(site_key);

my $ID = 0;

sub header_safe {
  my( $self, $string ) = @_;
  $string =~ s{\s+}{ }mxgs;
  $string =~ s{(['"<>\\])}{\\$1}mxgs;
  return $string =~ m{\A\s*(.*?)\s*\Z}mxs ? $1 : $string;
}


my %defaults = (
  'code'         => undef,  ## The cache key code for the form
  'data'         => {},
  'stage'        => 0,      ## Current stage in progress of form 0,1,2,3,4,...(n-1) confirm complete
  'highest_stage' => 0,
  'state'        => 'pending',  ## Current state of form object!
  'type'         => undef,  ## Type of form object
  'object_id'    => undef,  ## ID of entry being editted
  'view_url'     => undef,  ## The view url (undef if it uses the action to display the
);

# Form structure....

# page_0
#   section_0_0
#     element_0_0_0
#     element_0_0_1
#   section_0_1
#     element_0_1_0
#     element_0_1_1
#     element_0_1_2
# page_1
#   section_1_1
#     element_1_1_0
#   ...
#   ...
#   ...
#   ...

sub create_adaptor {
  my( $self, $type, $db_info ) = @_;
  my $adaptor;
  if( $type ) {
    my $class = "Pagesmith::Adaptor::$type";
    $self->dynamic_use( $class );
    $adaptor = $class->new( $db_info );
  } else {
    $adaptor = Pagesmith::Adaptor->new( $db_info );
  }
  $adaptor->set_r( $self->r );
  return $adaptor;
}

sub r {
  my $self = shift;
  return $self->{'_r'};
}

sub set_r {
  my( $self, $r ) = @_;
  $self->{'_r'} = $r;
  return $self;
}

sub apr {
  my $self = shift;
  return $self->{'_apr'};
}

sub param {
  my( $self, @attrs) = @_;
  return $self->apr->param( @attrs );
}

sub set_apr {
  my( $self, $apr ) = @_;
  $self->{'_apr'} = $apr;
  return $self;
}

#= Initialiser

sub set_user {
  my( $self, $user ) = @_;
  $self->{'user'} = $user;
  return $self;
}

sub get_user {
  my $self = shift;
  return $self->{'user'};
}

sub user {
  my $self = shift;
  return $self->SUPER::user( $self->r );
}

sub make_form_get {
  my $self = shift;
  $self->{'form_attributes'}{'method'} = 'get';
  return $self;
}

sub make_form_post {
  my $self = shift;
  $self->{'form_attributes'}{'method'} = 'post';
  return $self;
}

sub new {
  my( $class, $hash_ref ) = @_;
  # Copy hash ref to self - and copy defaults from above...
  my $self = {
    '_r' => $hash_ref->{'r'},
    '_apr' => $hash_ref->{'apr'},
    'attributes' => {},
    'user' => undef,
    'form_attributes'  => {
      'accept-charset' => 'UTF-8',
      'action' => undef,
      'method' => 'post',
      'enctype' => 'application/x-www-form-urlencoded',
    },
    'view_url'         => $hash_ref->{'view_url'}||undef,
    'form_id'          => undef,
    'object'           => undef,

## Entries used to create and store the stages of the form
    'current_stage'    => undef,                  # Current page when creating form
    'stages'           => {},                     # Pages to display
    'stage_order'      => [],                     # Order of stages
    'elements'         => {},

## Storing the buttons on the page!
#   'buttons'          => [],                      # Buttons on page..

    'response'         => undef,

    'cache_handle'     => exists $hash_ref->{'cache_handle'} ? $hash_ref->{'cache_handle'} : undef,
  };
## Copy stuff from the creation of the form object,
## This will include the form/object code or type/id, and any data stored
## against the form object.

  foreach( keys %defaults ) {
    $self->{$_} = exists $hash_ref->{$_} ? $hash_ref->{$_} : $defaults{$_};
  }

  $self->{'messages'} = [ map { Pagesmith::Form::Message->new( $_ ) } @{$hash_ref->{'messages'}||[]} ];
  $self->{'attributes'} = $hash_ref->{'attributes'}||{};

  bless $self, $class;
  $self->{'form_id'} = $hash_ref->{'form_id'} || 'form_'.$self->random_code;

  $self->{'config'} = Pagesmith::Form::Config->new( {
    'form_id'  => $self->{'form_id'},
    'options'  => $hash_ref->{'options'}||{},
    'classes'  => $hash_ref->{'classes'}||{},
    'form_url' => $self->action_url_get,
  } );

  # Generate the object! and if it fails to generate reset ID!

  $self->{'object_id'} = $self->default_id unless defined $self->{'object_id'};

  undef $self->{'object_id'} if $self->{'object_id'} && !$self->fetch_object(); ## Returns

  $self->add_attribute( 'ref', $self->apr->param( '__ref' ) || $self->r->headers_in->{'Referer'} );  ## Set the refererer

  $self->initialize_form         # Create form elements
       ->populate_object_values  # Load values from the object if it exists
       ->populate_user_values;   # Load values onto elements from the cache

  return $self;
}

sub populate_object_values {
  my $self = shift;
  return $self;
}

sub validate {
  my $self = shift;
  $_->validate( $self ) foreach $self->stages;
  $self->extra_validation; ## This is what is usually done "on-next!"
  return;
}

sub first_invalid_stage {
#@returns (int) the index of the first invalid page OR -1 if all pages are valid!
  my $self = shift;
  return firstidx { $_->is_invalid } $self->stages;
}

sub is_invalid {
#@return (true) if the form is in valid in any page!
  my $self = shift;
  return any { $_->is_invalid } $self->stages;
}

#= Accessors (used in form construction)

sub config {
  my $self = shift;
  return $self->{'config'};
}

sub attributes {
#@getter
  my $self = shift;
  return $self->{'attributes'};
}

sub add_attribute {
  my( $self, $type, $value ) = @_;
  $self->{'attributes'}{$type} = $value unless exists $self->{'attributes'}{$type};
  return $self;
}

sub delete_attribute {
  my( $self, $type ) = @_;
  delete $self->{'attributes'}{$type};
  return $self;
}

sub update_attribute {
  my( $self, $type, $value ) = @_;
  $self->{'attributes'}{$type} = $value;
  return $self;
}

sub attribute {
  my( $self, $type ) = @_;
  return $self->{'attributes'}{$type};
}

sub form_attributes {
#@getter
  my $self = shift;
  return $self->{'form_attributes'};
}

sub add_form_attribute {
#@param (self)
#@param (string) $type Type of form_attribute to set
#@param (string) $value Value of form_attribute to set
## Sets a form form_attribute - one of action, method, enctype
  my ( $self, $type, $value ) = @_;

  $self->{'form_attributes'}{$type} = $value;
  return $self;
}

sub classes {
#@param (self)
#@param (string) $type type of class to return
#@return (string+) list of classes
## Return the list of classes associated with the form!

  my( $self, $type ) = @_;
  return $self->config->classes( $type );
}

sub add_class {
#@param (self)
#@param (string) $class CSS class to add to form
  my ( $self, $type, $class ) = @_;
  $self->config->add_class( $type, $class);
  return $self;
}

sub secure {
  my $self = shift;
  return $self->{'secure'};
}

sub set_secure {
  my( $self, $secure ) = @_;
  $self->{'secure'} = defined $secure ? $secure : 1;
  return $self;
}

sub title {
  my $self = shift;
  return $self->{'title'};
}

sub set_title {
  my( $self, $title ) = @_;
  $self->{'title'} = $title;
  return $self;
}

sub has_file {
#@return (boolean) true if any stage has a file input box
  my $self = shift;
  return any { $_->has_file } $self->stages;
}

#h2 Accessors (not used in form construction)

#h2 Form construction methods

#h3 Adding and accessing stages

sub set_introduction {
  my( $self, $intro_data ) = @_;
  $self->{'introduction'} = $intro_data;
  return $self;
}

sub render_introduction {
  my $self = shift;
  return q() unless $self->{'introduction'};
  my $x = join q( ), $self->config->classes('section');
  my $html = $x ? qq(<div class="$x">) : q(<div>);
     $html .= sprintf "\n<h1>%s</h1>", encode_entities( $self->{'introduction'}{'caption'} ) if $self->{'introduction'}{'caption'};
     $html .= "\n".$self->{'introduction'}{'body'}."\n</div>";
  return $html;
}

sub add_confirmation_stage {
  my( $self, $stage_data, $caption ) = @_;
  return $self->_add_stage( 'Pagesmith::Form::Stage::Confirmation', $stage_data || 'Confirmation' , $caption )->set_next( 'Confirm' );
}

sub add_redirect_stage {
  my( $self, $stage_data, $caption ) = @_;
  return $self->_add_stage( 'Pagesmith::Form::Stage::Redirect', $stage_data || 'Redirect' , $caption )->set_next( 'X' );
}

sub add_error_stage {
  my( $self, $stage_data, $caption ) = @_;
  return $self->_add_stage( 'Pagesmith::Form::Stage::Error', $stage_data || 'Error' , $caption )->set_next( q() );
}

sub add_final_stage {
  my( $self, $stage_data, $caption ) = @_;
  return $self->_add_stage( 'Pagesmith::Form::Stage::Final', 'Completed', $caption );
}

sub add_stage {
  my( $self, $stage_data, $caption ) = @_;
  return $self->_add_stage( 'Pagesmith::Form::Stage', $stage_data, $caption );
}

sub _add_stage {
#@param (self)
#@param (string) $type
#@param (hash_ref|string) $stage_data Configuration of the new page
#@param (string)? $caption Caption for stage - if stage_data is just a scalar "ID"
#@return (Pagesmith::Form::Stage) Form stage added (or if already exists existing stage)
## Add a new form page (or return a previous defined one)

  my ( $self, $type, $stage_data, $caption ) = @_;

  unless( ref $stage_data ) {
    ( $caption = $stage_data ) =~ tr{_}{ } unless defined $caption;
    $stage_data = { 'id' => $stage_data, 'caption' => ucfirst $caption };
  }

  my $key = $stage_data->{'id'};
  unless ($key) {
    $key = $self->random_code;
    while ( exists $self->{'stages'}{$key} ) {
      $key = $self->random_code;
    }
    $stage_data->{'id'} = $key;
  }

  unless ( exists $self->{'stages'}{$key} ) {
    $self->{'stages'}{$key} ||= $type->new( $self, $stage_data );
    push @{ $self->{'stage_order'} }, $key;
  }
  $self->{'current_stage'} = $key;
  return $self->current_stage->set_object( $self->object );
}

sub current_stage {
#@param (self)
#@return (Pagesmith::Form::Stage) Current stage of form.
## Returns the current page of the form, if no page has been defined creates an _default_ page and uses that.
  my $self = shift;
  unless ( defined $self->{'current_stage'} ) {
    unless ( exists $self->{'stages'}{'_default_'} ) {
      $self->{'stages'}{'_default_'} ||= Pagesmith::Form::Stage->new($self);
      push @{ $self->{'stage_order'} }, '_default_';
    }
    $self->{'current_stage'} = '_default_';
  }
  return $self->{'stages'}{ $self->{'current_stage'} };
}

#h3 Adding and accessing sections

sub add_raw_section {
  my( $self, @section_data )  = @_;
  $self->current_stage->add_raw_section( @section_data );
  return $self->current_section;
}

sub add_readonly_section {
  my( $self, @section_data )  = @_;
  $self->current_stage->add_readonly_section( @section_data );
  return $self->current_section;
}

sub add_section {
  my( $self, @section_data )  = @_;
  $self->current_stage->add_section( @section_data );
  return $self->current_section;
}

sub current_section {
  my $self = shift;
  return $self->current_stage->current_section;
}

#h3 Adding elements

sub add_group {
  my ( $self, @params ) = @_;

  return $self->current_section->add_group(@params);
}

sub add {
#@param (self)
#@param (string) Type of element to add
#@param (hash_ref) Configuration for element
## Adds an element to the form.
  my ( $self, @params ) = @_;

  my $el = $self->current_section->add( @params );
## Store the new element onto the array of elements for the form (so we don't have to scan the tree later!)
  $self->{'elements'}{$el->code}||=[];
  push @{$self->{'elements'}{$el->code}}, $el;
  return $el;
}

sub populate_user_values {
  my $self = shift;
  foreach my $code ( keys %{$self->all_elements} ) {
    next unless exists $self->{'data'}{$code};
    foreach my $el ( $self->elements($code) ) {
      $el->set_user_data( @{ $self->{'data'}{$code} } );
    }
  }
  return $self;
}

sub get_data_from_elements {
  my $self = shift;
  my $form_data = {};
  foreach my $code (keys %{$self->all_elements||[]} ) {
    foreach my $el (@{$self->{'elements'}{$code}} ) {
      next if $el->do_not_store;
      push @{$form_data->{$code}}, $el->user_data;
    }
  }
  return $form_data;
}

sub all_elements {
#@ hashref of arrays
## Retrieve all elements in the form
  my $self = shift;
  return $self->{'elements'};
}

sub elements {
## Retrieve all elements of the form with a given code
  my( $self, $code ) = @_;
  return @{ $self->{'elements'}{$code}||[] };
}

sub element {
## Retrieve all elements of the form with a given code
  my( $self, $code ) = @_;
  return unless exists $self->{'elements'}{$code};
  return $self->{'elements'}{$code}[0];
}

#h3 Adding buttons and setting button text....

sub all_input_elements {
  my $self = shift;
  my @inputs;
  foreach my $stage ( $self->stages ) {
    foreach my $section ( $stage->sections ) {
      push @inputs, grep { $_->is_input } $section->elements;
    }
  }
  return @inputs;
}
sub set_next_text { ## These are now set on each of the sections!
  my( $self, $txt ) = @_;
  $self->current_stage->{'next_text'} = $txt;
  return $self;
}

sub set_prev_text {
  my( $self, $txt ) = @_;
  $self->current_stage->{'prev_text'} = $txt;
  return $self;
}

sub set_prev_stage {
  my( $self, $stage_code ) = @_;
  $self->current_stage->{'prev_stage'} = $stage_code;
  return $self;
}
sub add_reset_button {
  my ( $self, $action, $text, $title ) = @_;

  my $button = Pagesmith::Form::ResetButton->new( $self, {
    'form'    => $self->config->form_id,
    'id'      => $action,
    'code'    => $action,
    'caption' => $text,
    'hint'    => $title,
    'class'   => 'reset',
  } );
  push @{ $self->{'buttons'} }, $button;
  return $self;
}


sub add_button {
  my ( $self, $action, $text, $title, $stage_id ) = @_;

  my $class = $action eq 'cancel' ? 'cancel'
            : $action eq 'next'   ? 'next'
            : 'default-button';
  my $button = Pagesmith::Form::SubmitButton->new( $self, {
    'form'     => $self->config->form_id,
    'id'       => $action,
    'code'     => $action,
    'caption'  => $text,
    'hint'     => $title,
    'stage_id' => $stage_id,
    'class'    => $class,
  } );
  push @{ $self->{'buttons'} }, $button;
  return $self;
}

#h2 rendering methods....

sub render_extra {
  my $self = shift;
  return q();
}

## no critic (ExcessComplexity)

sub render_formprogress {
#@param ($self)
#@return (void)
  my $self = shift;
  return q() unless $self->stages;

  my @class = $self->classes( 'progress' );
  my $class_tags = @class ? sprintf ' class="%s"', join q( ), @class : q();
  my $html = "\n  <div$class_tags>";
  $html .= sprintf "\n    <h3>%s</h3><ul>", encode_entities( $self->{'progress_caption'} || 'Form progress' );

  my $highest_stage = $self->highest_stage;
  my $current_stage = $self->stage;
  my $first_invalid = $self->first_invalid_stage;

  my $stage_no = 0;
  my $link_temp = $self->action_url_get( { 'goto_#S#' => 1 } );
  $link_temp = q() if $self->state eq 'completed';
  foreach my $stage ( $self->stages ) {
    next if $stage->isa( 'Pagesmith::Form::Stage::Error' );
    my $text  = $stage->progress_caption;
    unless( $text ) {
      $stage_no++;
      next;
    }
    my @stage_class;
    ( my $link  = $link_temp ) =~ s{\#S\#}{$stage_no}mxs;
    if(
      $stage_no > $self->highest_stage ||
      $self->config->option( 'validate_before_next' ) && $stage_no > ($self->first_invalid_stage - 1) && $self->first_invalid_stage >=0
    ) {
      $link = q(); # Remove link
    }
    if( $stage_no <= $self->highest_stage ) {
      push @stage_class, $stage->is_invalid ? 'invalid' : 'valid';
    }
    if( $stage_no == $current_stage ) {
      push @stage_class, 'active';
      $link = q();
    }
    my $li_tags = @stage_class ? sprintf ' class="%s"', join q( ), @stage_class : q();
    if( $link ) {
      $html .= sprintf qq(\n      <li%s><a href="%s">%s</a></li>), $li_tags, encode_entities( $link ), encode_entities( $text );
    } else {
      $html .= sprintf qq(\n      <li%s>%s</li>), $li_tags, encode_entities( $text );
    }
    $stage_no++;
  }

  $html .= sprintf qq(\n      <li><a href="%s">%s</a></li>), encode_entities( $self->action_url_get( { 'jumbo' => 1 } ) ), 'All pages'
    if $self->config->option('jumbo_link');
  $html .= sprintf qq(\n      <li><a href="%s">%s</a></li>), encode_entities( $self->action_url_get( { 'paper' => 1 } ) ), 'Paper copy'
    if $self->config->option('paper_link');

  $html .= "\n    </ul>\n  </div>";
  return $html;
}

sub render {
  ##render appropriate page
  my $self = shift;
  my $stage = $self->active_stage;

  if( $self->stage && defined $stage->back_stage ) {
    $self->add_button(    'goto_'.$stage->back_stage,    $stage->get_back() || 'Previous' , 'Return to previous page' );
  } elsif(
    $self->stage &&
    ! $stage->is_type( 'Error' ) &&
    ! $self->previous_stage_object->is_type( 'Confirmation' )
  ) {
    $self->add_button(    'previous',    $stage->get_back() || 'Previous' , 'Return to previous page' );
  }

  $self->add_button(       'cancel',   'Cancel', 'Cancel form' ) if $self->option( 'cancel_button' ) && $self->state ne 'completed';

  $self->add_reset_button( 'reset',    'Reset',  'Reset current page of form'  )
    if $stage->has_input_elements && ! $self->option('no_reset');

  $self->add_button(       'next',     $stage->get_next() || 'Next' ,     'Submit changes and go to next page' )
    unless $stage->is_type( 'Error' ) || $stage->is_type( 'Final' ) || $self->stage == $self->stages - 1;

  my $buttons = $self->_render_buttons;
  if( $buttons ) {
    $stage->add_button_html( 'top', $buttons ) if exists $self->{'_extra_buttons'} && $self->{'_extra_buttons'} eq 'top';
    $stage->add_button_html( 'bottom', $buttons );
  }
  if( $stage->has_file ) {    #  File types must always be multipart Posts
    $self->add_form_attribute( 'method', 'post' );
    $self->force_form_code;
    $self->add_class( 'form', 'upload' );
    $self->add_form_attribute( 'enctype', 'multipart/form-data' );
  }
  my $html = $self->_trim(
    $self->render_form_start.
    $self->render_messages.
    $stage->render($self).
    $self->render_form_end );
  return $html unless $self->config->option( 'is_action' );
  ## This is used by Action...
  ( my $template = $self->page_template ) =~ s{<%\sForm\s%>}{$html}mxs;
  $template =~ s{<%\sIntroduction\s%>}{$self->render_introduction}mxse;
  $template =~ s{<%\sFormProgress\s%>}{$self->render_formprogress}mxse;
  $template =~ s{<%\sExtra\s%>}{$self->render_extra}mxse;
  return $template;
}

# use critic
sub render_as_one {
  ##render appropriate page
  my $self = shift;

  if ( $self->has_file ) {    #  File types must always be multipart Posts
    $self->add_form_attribute( 'method', 'post' );
    $self->add_class('form', 'upload');
    $self->add_form_attribute( 'enctype', 'multipart/form-data' );
  }

  my $buttons = $self->_render_buttons;

  return $self->_trim(
    join q(),
     $self->render_form_start,
     $self->render_messages,
     ( map { $_->render($self) } $self->stages ),
     $self->render_form_end );
}


sub render_email {
  my $self = shift;
  return join q(), map { $_->render_email($self) } $self->stages;
}

sub render_cons {
#@param ($self)
#@param (boolean) $flag
#@return Read only version of form (with or without the wrapping form element)
  my ( $self, $flag ) = @_;
  my $res = q();
     $res .= $self->render_form_start if $flag;
     $res .= join q(), $self->render_messages, map { $_->render_cons($self) } $self->stages;
     $res .= $self->render_form_end if $flag;
  return $res;
}

sub render_paper {

#@param ($self)
#@param (boolean) $flag
#@return Read only version of form (with or without the wrapping form element)
  my ( $self, $flag ) = @_;
  return $self->_trim( join q(), map { $_->render_paper($self) } $self->stages );
}

#= Renderer support functions

sub render_form_start {
  my $self   = shift;

  my $t = join q( ), $self->classes( 'form' );
  if( $t )  {
    $self->{'form_attributes'}{'class'} = $t ;
  } else {
    delete $self->{'form_attributes'}{'class'};
  }
  $self->{'form_attributes'}{'id'} = $self->id;

  my $submission_url = $self->action_url_post( );

  $self->{'form_attributes'}{'action'} = $self->can('overide_url') ? $self->overide_url : $submission_url->{'url'};

  my $output = q();
  $output .= sprintf qq(\n<form %s>\n<div>\n  <input type="hidden" name="action" value="" />\n  <input type="hidden" name="__utf8" value="&pound;" />),
    join  q(),
    map { sprintf ' %s="%s"',
      encode_entities( $_ ),
      encode_entities( $self->{'form_attributes'}{$_} )
    }
    grep { $self->{'form_attributes'}{$_} } sort keys %{ $self->{'form_attributes'} };
  $output .= join qq(\n  ), q(), map {
    sprintf '<input type="hidden" name="%s" value="%s" />', encode_entities( $_ ), encode_entities( $submission_url->{'pars'}{$_} )
  } sort keys %{$submission_url->{'pars'}};

  return $output;
}

sub render_form_end {
  my $self = shift;
  return "\n</div>\n</form>";
}

sub render_messages {
  my $self = shift;
  return q() unless @{$self->{'messages'}};
  my @messages  = sort {
    $a->num_level <=> $b->num_level ||
    $a->text cmp $b->text
  } @{$self->{'messages'}};
  my $max_level = sprintf 'box-%s', $messages[0]->level;
  my $class     = join q( ), $max_level, $self->config->classes('section');
  my $html      = q();
  foreach my $message ( @messages ) {
    $html .= sprintf  qq(\n      <li class="form_%s">%s</li>), $message->level, $message->html;
  }
  $self->{'messages'} = [];
  $self->store if $self->code;
  ## no critic (ImplicitNewlines)
  return sprintf '
  <div class="%s">
    <h3>Errors and warnings</h3>
    <ul>%s
    </ul>
  </div>', $class, $html;
  ##use critic
}

#h2 URL methods (post,get and view!)
sub action_url_get {
  my( $self, $parameters ) = @_;
  return $self->action_url( 'get', $parameters );
}

sub action_url_post {
  my( $self, $parameters ) = @_;
  return $self->action_url( 'post', $parameters );
}

sub action_url {
  my( $self, $method, $parameters ) = @_;
  $parameters = {} unless defined $parameters && $parameters;
  my $url = '/form';
  $url = 'https://'.$self->r->hostname.'/form' if $self->secure;
  if( $self->{'code'} ) {
    $url .= "/-$self->{'code'}";
  } else {
    ( my $type = $self->{'type'}||q() ) =~ s{::}{_}mxs;
    $url .= "/$type";
    $url .= q(/).$self->object_id if $self->object_id;
    $parameters->{'__ref'} = $self->attribute( 'ref' )||q();
  }
  if( !$self->{'code'} && $self->view_url ) {
    $parameters->{'view_url'} = $self->view_url;
  }
  if( $method eq 'post' ) {
    my $ret_value = { 'url' => $url, 'pars' => $parameters };
    return $ret_value;
  }
  if( $parameters && keys %{$parameters} ) {
    $url .= q(?).join q(;), map { $_ .q(=). uri_escape_utf8( $parameters->{$_} ) } sort keys %{$parameters};
  }
  return $url;
}

sub view_url {
  my $self = shift;
  return $self->{'view_url'}; ## This is the raw URL of the page!
}

sub set_view_url {
  my( $self, $url )  = @_;
  return $self unless defined $url;
  my $regex_string = '(\?(|.*[&;]))'.quotemeta($self->{'type'}).'=[-\w]{22}(;?)';
  $url =~ s{$regex_string}{$1}mxs;
  $self->{'view_url'} = $url;
  return $self;
}

sub type {
  my $self = shift;
  return $self->{'type'};
}

sub destroy_object {
  my $self = shift;
  return $self unless $self->{'code'}; ## No cache object!
  unless( $self->{'cache_handle'} ) {
    $self->{'cache_handle'} = Pagesmith::Cache->new( 'form', $self->{'code'}, undef, site_key );
  }
  $self->{'cache_handle'}->unset;
  return $self;
}
## Store the form object to memory cache!
sub generate_checksum {
  my( $self, $user_data ) = @_;
  return safe_md5( $self->raw_dumper( $user_data, 'user_data' ) );
}

sub validate_checksum {
  my( $self, $checksum ) = @_;
  return $checksum eq safe_md5( $self->raw_dumper( $self->get_data_from_elements, 'user_data' ) );
}

sub store {
  my $self = shift;
  unless( $self->{'cache_handle'} ) {
    $self->{'code'}         ||= $self->safe_uuid;
    $self->config->set_option( 'code', $self->{'code'} );
    $self->{'cache_handle'}   = Pagesmith::Cache->new( 'form', $self->{'code'}, undef, site_key );
  }

  my $data_to_store = { map { $_ => $self->{$_} } keys %defaults };
  ## For error pages we don't store the error page the user is on - but the last stage they were on!
  $data_to_store->{'stage'}     = $self->{'stage_to_store'} if exists $self->{'stage_to_store'};
  $data_to_store->{'data'}      = $self->get_data_from_elements;
  $data_to_store->{'checksum'}  = $self->generate_checksum( $data_to_store->{'data'} );
  $data_to_store->{'messages'}  = [
    map { { 'level' => $_->level, 'text' => $_->text, 'raw' => $_->raw } }
    @{ $self->{'messages'}||[] } ];
  $data_to_store->{'attributes'}  = $self->{'attributes'};

  $self->{'cache_handle'}->set( $data_to_store );
  return $self;
}

## Configuration actions!

sub force_form_code {
## This forces the form to have a code EVEN it is the first time that it is used
  my $self = shift;
  return $self if $self->{'code'};
  return $self->store();
  # means that you won't be able to submit the form twice - (or go back to the first page and
  # submit the form from their twice!)
  # It is quite cool that we get this effectively for free! I do like free code!!
}

sub update_form_from_data {
  my $self = shift;
  return $self;
}

sub fetch_object {
  my $self = shift;
  carp 'You must specify an qw(submission function [submit_form] on the form object to action the form at then end)';
  return;
}

sub submit_form {
  my $self = shift;
  carp 'You must specify an qw(submission function [submit_form] on the form object to action the form at then end)';
  return;
}

sub initialize_form {
  my $self = shift;
  carp 'You must specify an qw(initialisation function [initialize_form] on the form object to generate the elements)';
  return;
}

sub set_option {
  my( $self, $key, $value ) = @_;
  $value = 1 unless defined $value;
  $self->config->set_option( $key, $value );
  return $self;
}

sub option {
  my( $self, $key ) = @_;
  return $self->config->option( $key );
}

## Error handling!
sub add_message {
  my( $self, $message, $level, $raw ) = @_;
  push @{$self->{'messages'} }, Pagesmith::Form::Message->new( { 'level' => $level, 'text' => $message, 'raw' => ($raw || q()) } );
  return $self;
}

sub messages {
  my $self = shift;
  return @{$self->{'messages'}};
}

sub has_message {
  my( $self, $flag ) = @_;
  return any { $_->level eq $flag } @{$self->{'messges'}} if $flag;
  return @{$self->{'messages'}} ? 1 : 0;
}

sub add_info {
  my( $self, $info_msg, $raw ) = @_;
  return $self->add_message( $info_msg, 'info', $raw||q() );
}

sub has_info {
  my $self = shift;
  return $self->has_message( 'info' );
}

sub add_msg {
  my( $self, $msg, $raw ) = @_;
  return $self->add_message( $msg, 'msg', ($raw||q()) );
}

sub has_msg {
  my $self = shift;
  return $self->has_message( 'msg' );
}

sub add_warn {
  my( $self, $warn, $raw ) = @_;
  return $self->add_message( $warn, 'warn', $raw||q() );
}

sub has_warn {
  my $self = shift;
  return $self->has_message( 'warn' );
}

sub add_error {
  my( $self, $error, $raw ) = @_;
  return $self->add_message( $error, 'error', $raw||q() );
}

sub has_error {
  my $self = shift;
  return $self->has_message( 'error' );
}

sub page {
  my( $self, $code ) = @_;
  return $self->{'stages'}{$code};
}

sub n_stages {
  my $self = shift;
  return scalar @{ $self->{'stage_order'} };
}

sub stages {
  my $self = shift;
  return map { $self->{'stages'}{$_} } @{ $self->{'stage_order'} };
}

sub action {
  my $self = shift;
  return $self->{'form_attributes'}{'action'};
}

sub response {
  my $self = shift;
  return $self->{'response'};
}

sub code {
  my $self = shift;
  return $self->{'code'};
}

sub user_data {
  my $self = shift;
  return $self->{'data'};
}

sub prefix {
  my $self = shift;
  return $self->{'prefix'};
}

sub stage {
  my $self = shift;
  return $self->{'stage'};
}

sub stage_object {
  my $self = shift;
  return unless exists $self->{'stage_order'}[ $self->{'stage'} ];
  return $self->{'stages'}{ $self->{'stage_order'}[ $self->{'stage'} ] };
}

sub first_stage {
  my $self =  shift;
  return $self->{'stages'}{ $self->{'stage_order'}[0] };
}

sub highest_stage {
  my $self = shift;
  return $self->{'highest_stage'};
}

sub goto_previous_stage {
  my $self = shift;
  my $stage = $self->stage - 1;
  $stage = 0 if $stage < 0;
  my $fis = $self->first_invalid_stage;
  $stage = $fis if $fis >= 0 && $self->option('validate_before_next') && $stage > $fis;
  return $self->set_stage( $stage );
}

sub goto_stage {
  my( $self, $stage ) = @_;
  $stage = 0 if $stage < 0;
  $stage = $self->{'highest_stage'} if $stage > $self->{'highest_stage'};
  my $fis = $self->first_invalid_stage;
  $stage = $fis if $fis >= 0 && $self->option('validate_before_next') && $stage > $fis;
  return $self->set_stage( $stage );
}

sub evaluate_logic {
  my( $self, $logic_ref ) = @_;
## Check conditions... and if not true call goto_next_stage again!
###$self->dumper( $logic_ref );
  my $logic_type = $logic_ref->{'type'};
  my @logic      = @{$logic_ref->{'conditions'}||[]};
  return $logic_type eq 'all' || $logic_type eq 'any';
  foreach my $row ( @logic ) {
    my $type  = $row->{'type'};
    my $value = $row->{'value'};
    my $val   = $self->element( $row->{'name'} )->value;
    my $flag = $type eq 'exact'        ? $val eq $value
             : $type eq 'contains'     ? index $val, $value >= 0
             : $type eq 'starts_with'  ? index $val, $value == 0
             : $type eq 'ends_with'    ? rindex $val, $value == length $value - length $val
             : $type eq 'true'         ? $val
             : 0
             ;
    if( $logic_type eq 'all') {
      return 0 unless $flag;
    } elsif( $logic_type eq 'any' ) {
      return 1 if $flag;
    } elsif( $logic_type eq 'none' ) {
      return 0 if $flag;
    } else {
      return 1 unless $flag;
    }
  }
  return 1 if $logic_type eq 'all' || $logic_type eq 'none';
  return 0;
}

sub goto_next_stage {
  my $self = shift;
  return $self if $self->active_stage->isa( 'Pagesmith::Form::Stage::Error' ); ## Don't go forward past an error stage!

  my $stage = $self->stage + 1;
  my $fis = $self->first_invalid_stage;
  $stage = $fis if $fis >= 0 && $self->option('validate_before_next') && $stage > $fis;
  return $self->set_stage( $stage );
}

sub set_stage_by_name {
  my( $self, $name ) = @_;
  my $new_stage = 0;
  foreach my $key ( @{ $self->{'stage_order'} } ) {
    return $self->set_stage( $new_stage ) if $key eq $name;
    $new_stage++;
  }
  return $self;
}

sub set_stage {
  my( $self, $new_stage ) = @_;

  my $current_stage = $self->stage;
  my $stages = $self->stages;

  $new_stage = $self->stages - 1 if $new_stage >= $self->stages;

  my $new_stage_is_error_stage =
    $self->{'stages'}{ $self->{'stage_order'}[ $new_stage ] }->is_type( 'Error' );

  unless( $new_stage_is_error_stage ) {
    my $fis = $self->first_invalid_stage;
    $new_stage = $fis if $fis >= 0 && $self->option('validate_before_next') && $new_stage > $fis;
  }

  $self->{'stage'} = $new_stage;

  if( $new_stage_is_error_stage ) {
    $self->{'stage_to_store'} = $current_stage ; ## Don't store error stages!
  } else {
    delete $self->{'stage_to_store'} if exists $self->{'stage_to_store'};
    $self->{'highest_stage'} = $new_stage if $new_stage > $self->{'highest_stage'};
  }

  return $self;
}

sub active_stage {
  my $self  = shift;
  my @stages = $self->stages;
  return $stages[ $self->stage ];
}

sub previous_stage_object {
  my $self = shift;
  my $previous_stage = $self->{'stage'} - 1;
  return if $previous_stage < 0;
  return unless exists $self->{'stage_order'}[ $previous_stage ];
  return $self->{'stages'}{ $self->{'stage_order'}[ $previous_stage ] };
}

##no critic (BuiltinHomonyms)
sub state {
  my $self = shift;
  return $self->{'state'};
}

##use critic (BuiltinHomonyms)
sub errors {
  my $self = shift;
  return $self->{'errors'};
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub object {
  my $self = shift;
  return $self->{'object'};
}

sub set_object {
  my( $self, $core_object ) = @_;
  $self->{'object'} = $core_object;
  return $self;
}

sub object_id {
  my $self = shift;
  return $self->{'object_id'};
}

sub set_object_id {
  my( $self, $id ) = @_;
  $self->{'object_id'} = $id;
  return $self;
}


sub _render_buttons {
  my $self = shift;

  return unless @{ $self->{'buttons'}||[] };

  my $class = $self->{'form_attributes'}{'class'}||q();
  $class =~ s{check}{}mxs;

  my $buttons = { 'right' => [], 'left' => [] };
  foreach( @{$self->{'buttons'}} ) {
    push @{$buttons->{ $_->{'code'} eq 'next' ? 'right' : 'left' }}, $_;
  }
  my $output = qq(\n      <div class="button-row">\n      <div class="button-default">);
  if( @{$buttons->{'right'}} ) {
    $output .= sprintf "\n        %s", $_->render foreach @{ $buttons->{'right'} };
    $output .= "\n      ";
  } else {
    $output .= '&nbsp;';
  }
  $output .= qq(</div>\n        <div class="button-other">);
  if( @{$buttons->{'left'}} ) {
    $output .= sprintf "\n        %s", $_->render foreach @{ $buttons->{'left'} };
    $output .= "\n      ";
  } else {
    $output .= '&nbsp;';
  }
  $output .= qq(</div>\n      </div>);

  return $output;
}

sub add_hidden {
  my ( $self, $hidden ) = @_;

  foreach ( keys %{ $hidden || {} } ) {
    $self->add( 'Hidden',{ 'code'  => $_, 'value' => $hidden->{$_} } );
  }
  return;
}

# Render the FORM tag and its contents

#= Renderer methods
# - render
# - render_as_one
# - render read only
# - render paper

sub _trim {
## Remove empty dl/ul/ols that may have got into form!!
  my ( $self, $string ) = @_;
  $string =~ s{<([oud]l)[^>]*>\s*</\1>}{}smxg;
  return $string;
}

sub completed {
  my $self = shift;
  $self->{'state'} = 'completed';
  return $self;
}

sub is_completed {
  my $self = shift;
  return $self->state eq 'completed';
}

sub update_from_apr {
  my $self = shift;
  my $pound = $self->apr->param('__utf8')||q();
  ## no critic (EscapedCharacters)
  my $flag = $pound eq "\xC2\xA3" ? 'utf-8'
           : $pound eq "\x00A3"   ? 'utf-16'
           : $pound eq "\xA3"     ? 'ascii'
           :                          'unk'
           ;
  ## use critic
  if( $self->option('show_all_stages') ) {
    ## If we show all the stages of the form at once!
    ## Then we need to update all elements at once!
    $_->update_from_apr( $self->apr, $flag ) foreach $self->stages;
  } else {
  # Loop through each of the elements of the current stage of the form,
  # and update element from the APR object;
    $self->stage_object->update_from_apr( $self->apr, $flag );
  }
  return $self;
}

sub generate_form_key {
  my $self = shift;
  return $self;
}

## Access control stuff!
## In general form elements are edittable by anyone!

sub default_id {
  my $self = shift;
  return;
}

sub can_view {
  my $self = shift;
  return;
}

sub cant_create {
  my $self = shift;
  return;
}

sub cant_edit {
  my $self = shift;
  return;
}

## Stub functions which get executed when performing actions

sub on_confirmation {
#@param $stage
#@return no value if confirmed

  my $self = shift;
  return;
}

sub on_cancel {
#@param $stage
#@return no value if cancel should just destroy object and jump to referer!
#  otherwise do something and return status code!
  my $self = shift;
  return;
}

sub extra_validation {
  my $self = shift;
  return;
}

sub on_goto {
  my( $self, $current_stage, $new_stage_id ) = @_;
  return;
}

sub on_next {
  my $self = shift;
  return;
}

sub on_back {
  my $self = shift;
  return;
}


sub on_redirect {
#@param $stage
#@return URL or null
# return a URL if the redirection should take place!
  my( $self, $stage ) = @_;
  return;
}

sub on_error {
  my $self = shift;
  return;
}

1;
