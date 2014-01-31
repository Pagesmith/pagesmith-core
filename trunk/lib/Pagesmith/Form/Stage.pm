package Pagesmith::Form::Stage;

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

use base qw( Pagesmith::Form::Root );

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use List::MoreUtils qw(any);

use Pagesmith::Form::Section;
use Pagesmith::Form::Section::Raw;
use Pagesmith::Form::Section::Readonly;

my $_offset = 0;

sub r {
  my $self = shift;
  return $self->{'r'};
}

sub new {
  my ( $class, $form, $page_data ) = @_;
  my $self = {
    'object'          => $form->object,
    'config'          => $form->config,
    'id'              => $page_data->{'id'} || $form->config->next_id,
    'r'               => $form->r,
    'caption'         => $page_data->{'caption'},
    'logic_type'      => 'any', ## none (0), any (>0), all (N), not_all (<N), 'at_least_\d', 'at_most_\d',
    'logic'           => [],
    'buttons'         => [],
    'sections'        => {},
    'section_order'   => [],
    'enabled'          => 'yes',
    'required'         => 'yes',
    'current_section' => undef,
  };
  bless $self, $class;
  return $self;
}

sub progress_caption {
  my $self = shift;
  return $self->{'progress_caption'} if exists $self->{'progress_caption'};
  return $self->caption || ($self->sections)[0]->caption || 'Untitled';
}

sub set_progress_caption {
  my( $self, $caption ) = @_;
  $self->{'progress_caption'} = $caption;
  return $self;
}

sub validate {
  my( $self, $form ) = @_;
  $_->validate( $form ) foreach $self->sections;
  return $self;
}

#h2. Checks on the form

sub is_invalid {
  my $self = shift;
  return any { $_->is_invalid } $self->sections;
}

sub has_input_elements {
  my $self = shift;
  return any { $_->has_input_elements } $self->sections;
}

#h2. accessors

sub get_next {
  my $self = shift;
  return $self->{'next'};
}

sub get_back {
  my $self = shift;
  return $self->{'back'};
}

sub set_next {
  my( $self, $value ) = @_;
  $self->{'next'} = $value;
  return $self;
}

sub set_back {
  my( $self, $value ) = @_;
  $self->{'back'} = $value;
  return $self;
}

sub back_stage {
  my $self = shift;
  return $self->{'back_stage'};
}

sub set_back_stage {
  my( $self, $value ) = @_;
  $self->{'back_stage'} = $value;
  return $self;
}

sub config {
  my $self = shift;
  return $self->{'config'};
}

sub update_from_apr {
  my( $self, $apr, $flag ) = @_;
  $_->update_from_apr( $apr, $flag ) foreach $self->sections;
  return $self;
}

## Accessors
sub set_id {
  my( $self, $value ) = @_;
  $self->{'id'} = $value;
  return;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub set_user_data {
  my( $self, $value ) = @_;
  $self->{'user_data'} = $value;
  return;
}

sub user_data {
  my $self = shift;
  return $self->{'user_data'};
}

sub set_caption {
  my( $self, $value ) = @_;
  $self->{'caption'} = $value;
  return;
}

sub caption {
  my $self = shift;
  return $self->{'caption'};
}

sub set_object {
  my( $self, $value ) = @_;
  $self->{'object'} = $value;
  return $self;
}

sub object {
  my $self = shift;
  return $self->{'object'};
}

sub sections {
  my $self = shift;
  return map { $self->{'sections'}{$_} } @{ $self->{'section_order'} };
}

sub has_file {
  my $self = shift;
  return any { $_->has_file } $self->sections;
}

sub is_type {
  my( $self, $type ) = @_;
  return $self->isa( "Pagesmith::Form::Stage::$type" );
}

sub type {
  my $self = shift;
  foreach ( qw(Error Final Redirect Confirmation) ) {
    return $_ if $self->isa( "Pagesmith::Form::Stage::$_" );
  }
  return q();
}

## Adding sections...
sub add_raw_section {

#@param (self)
#@param (hashref) $page_data Configuration of the new section
#@return (Pagesmith::Form::Section) Form page added (or if already exists existing page)
## Add a new form section (or return a previous defined one)

  my ( $self, $section_data, $id ) = @_;

  unless( ref $section_data eq 'HASH' ) {
    if( defined $id ) {
      $section_data = { 'body' => $section_data, 'id' => $id };
    } else {
      $section_data = { 'body' => $section_data };
    }
  }
  $section_data->{'id'} ||= $self->config->next_id;
  my $key = $section_data->{'id'};

  unless ( exists $self->{'sections'}{$key} ) {
    $self->{'sections'}{$key} = Pagesmith::Form::Section::Raw->new( $self, $section_data );
    push @{ $self->{'section_order'} }, $key;
  }
  $self->{'current_section'} = $key;
  return $self->current_section;
}

## Adding sections...
sub add_readonly_section {

#@param (self)
#@param (hashref) $page_data Configuration of the new section
#@return (Pagesmith::Form::Section) Form page added (or if already exists existing page)
## Add a new form section (or return a previous defined one)

  my ( $self, $section_data ) = @_;

  $section_data = { 'caption' => $section_data } unless ref $section_data eq 'HASH';

  $section_data->{'id'} ||= $self->config->next_id;
  my $key = $section_data->{'id'};

  unless ( exists $self->{'sections'}{$key} ) {
    $self->{'sections'}{$key} = Pagesmith::Form::Section::Readonly->new( $self, $section_data );
    push @{ $self->{'section_order'} }, $key;
  }
  $self->{'current_section'} = $key;
  return $self->current_section;
}

sub unshift_section {
#@param (self)
#@param (hashref) $page_data Configuration of the new section
#@return (Pagesmith::Form::Section) Form page added (or if already exists existing page)
## Add a new form section (or return a previous defined one)

  my ( $self, $section_data, $caption ) = @_;
  unless( ref $section_data ) {
    ( $caption = $section_data ) =~ tr{_}{ } unless defined $caption;
    $section_data = { 'id' => $section_data, 'caption' => ucfirst $caption };
  }
  $section_data->{'id'} ||= $self->config->next_id;
  my $key = $section_data->{'id'};

  unless ( exists $self->{'sections'}{$key} ) {
    $self->{'sections'}{$key} = Pagesmith::Form::Section->new( $self, $section_data );
    $self->{'sections'}{$key}->set_object( $self->object );
    unshift @{ $self->{'section_order'} }, $key;
  }
  $self->{'current_section'} = $key;
  return $self->current_section;
}

sub add_section {
#@param (self)
#@param (hashref) $page_data Configuration of the new section
#@return (Pagesmith::Form::Section) Form page added (or if already exists existing page)
## Add a new form section (or return a previous defined one)

  my ( $self, $section_data, $caption ) = @_;
  unless( ref $section_data ) {
    ( $caption = $section_data ) =~ tr{_}{ } unless defined $caption;
    $section_data = { 'id' => $section_data, 'caption' => ucfirst $caption };
  }
  $section_data->{'id'} ||= $self->config->next_id;
  my $key = $section_data->{'id'};

  unless ( exists $self->{'sections'}{$key} ) {
    $self->{'sections'}{$key} = Pagesmith::Form::Section->new( $self, $section_data );
    $self->{'sections'}{$key}->set_object( $self->object );
    push @{ $self->{'section_order'} }, $key;
  }
  $self->{'current_section'} = $key;
  return $self->current_section;
}

sub current_section {

#@param (self)
## Returns the current section of the page
  my $self = shift;

  unless ( defined $self->{'current_section'} ) {
    unless ( exists $self->{'sections'}{'_default_'} ) {
      $self->{'sections'}{'_default_'} = Pagesmith::Form::Section->new($self);
      $self->{'sections'}{'_default_'}->set_object( $self->object );
      push @{ $self->{'section_order'} }, '_default_';
    }
    $self->{'current_section'} = '_default_';
  }
  return $self->{'sections'}{ $self->{'current_section'} };
}

sub add_group {
  my( $self, @params ) = @_;
  return $self->current_section->add_group(@params);
}

sub add {
  my( $self, @params ) = @_;
  return $self->current_section->add(@params);
}

sub render_readonly {
  my( $self, $form ) = @_;
  return join q(), map { $_->render_readonly( $form ) } $self->sections;
}

sub render_email {
  my( $self, $form ) = @_;
  return join q(), map { $_->render_email( $form ) } $self->sections;
}

sub render_paper {
  my( $self, $form ) = @_;
  return join q(), map { $_->render_paper( $form ) } $self->sections;
}

sub add_button_html {
  my( $self, $pos, $html ) = @_;
  my @Q = $self->sections;
  return $self unless @Q;
  ## If position is top we add the buttons to the top of the first section of the page
  $Q[0 ]->add_button_html( 'top',    $html ) if $pos eq 'top';
  ## If position is at the bottom we add the buttons to the bottom of the last section of the page
  $Q[-1]->add_button_html( 'bottom', $html ) if $pos eq 'bottom';
  return $self;
}

sub render {
  my( $self, $form ) = @_;
  my $output = sprintf qq(\n  <div id="%s_%s">), encode_entities( $self->config->form_id ), encode_entities( $self->id );
  $output .= sprintf "<h2>%s</h2>\n", encode_entities( $self->caption ) if $self->caption && $self->config->option( 'show_page_titles' );
  foreach ($self->sections) {
    $output .= $_->render( $form );
  }
  $output .= "\n  </div>";
  return $output;
}

sub completed {
  return 1;
}
1;
