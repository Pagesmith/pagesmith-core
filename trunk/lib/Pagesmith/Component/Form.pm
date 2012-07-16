package Pagesmith::Component::Form;

## Component to render form
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

use base qw(Pagesmith::Component);

use URI::Escape qw(uri_escape_utf8);
use HTML::Entities qw(encode_entities);
use Apache2::URI;

## Form parameters
## [0]   $form module name - prefixed with Pagesmith::MyForm

#=for notes
# To use a form in a component ... default is to view the first page of the form
#
# (1) View the form ....
# (2) `-> jump to the PS:A:F
# (3) WHICH ADDS A PARAMETER WITH THE SAME NAME AS THE FORM TO THE PAGE
# (4) so page becomes http://domain/research/contact.html?My_Form=6542678536486576864358687346
#
# <% Form FormType %>
# <% Form Formname readonly %>
# <% Form Generic form_x _id_ {parameter_name} %>
##

sub execute {
  my $self = shift;

  my $form_type   = $self->safe_module_name( $self->next_par );
  my $form_object;
  if( $self->apr->param( $form_type ) ) {
    $form_object  = $self->form_by_code( $self->apr->param( $form_type ) );
  } elsif( $form_type eq 'Generic' ) {
    my $generic_type = $self->next_par;
    ( my $key = 'Generic_'.$generic_type ) =~ s{\W+}{_}mxgs;
    if( $self->apr->param( $key ) ) {
      $form_object  = $self->form_by_code( $self->apr->param( $key ) );
    }
  }
  unless( $form_object ) {
    if( $form_type eq 'Generic' ) {
      my $generic_type = $self->next_par;
      ( my $key = 'Generic_'.$generic_type ) =~ s{\W+}{_}mxgs;
      $form_object = $self->generic_form( $generic_type, $self->next_par||undef, $self->r->unparsed_uri );
    } else {
      $form_object  = $self->form( $self->safe_module_name( $form_type ), $self->next_par||undef, $self->r->unparsed_uri );
    }
  }

  ## Do we now have a form object!
  return '<h3>Unable to generate form object!</h3>' unless $form_object;

  ## Set the view URL - this is the URL of the page, but remove the form specific bits!
  my $html = $form_object->render();
  $self->form_progress( $form_object ) if $self->option( 'progress' ) || $form_object->config->option('progress_panel');
  $self->_parse( \$html )              if $self->option( 'parse'    ); # Only need to enable if form is inserting <% %> blocks!

  return $html;
}

## Set up progress of form!
sub _goto_url {

#@param ($self)
#@param (string)  $url Base url
#@param (int)     $stage Stage of form
#@return (string) Full URL for this entry
  my ( $self, $form_obj, $stage ) = @_;
  return;
}

sub form_progress {

#@param ($self)
#@param (Pagesmith::MyForm) $form_obj
#@param (boolean) $paper_copy
#@return (void)
  my ( $self, $form_obj, $paper_copy ) = @_;

  my $progess_href = $self->init_store( 'form_progress-'.$form_obj->type, {
      'caption' => $form_obj->{'progress_caption'} || 'Form progress',
      'pages' => [],
  } );

  my $stage = 0;
  foreach ( $form_obj->pages ) {
    my $active_stage = $stage eq $form_obj->stage;
    my $c = $_->caption || ( $_->sections )[0]->caption || 'Untitled';
    push @{ $progess_href->{'pages'} }, {
      'href' => $_->completed && ( !$active_stage || $paper_copy )
      ? $form_obj->action_url( 'goto', { 'stage' => $stage } )
      : q(),    # No link on active page!
      'caption' => ( $active_stage ? '<strong>' : q() )
        . encode_entities($c)
        . ( $active_stage ? '</strong>' : q() ),    # Embolden active page link!
    };
    $stage++;
  }

  if ( $form_obj->config->option('confirmation_page') ) {
    my $active_stage = $form_obj->stage == $form_obj->confirmation;
    push @{ $progess_href->{'pages'} }, undef, {
      'href' => $form_obj->completed
        && !$active_stage ? $form_obj->action_url('confirm', {} ) : q(),    # No link on active page!
      'caption' => ( $active_stage ? '<strong>' : q() )
        . encode_entities('Confirmation')
        . ( $active_stage ? '</strong>' : q() ),                                                      # Embolden active page link!
    };
  }
  if ( $form_obj->config->option('paper_link') ) {
    push @{ $progess_href->{'pages'} }, undef, {
      'href'    => $form_obj->view_url( 'paper' ),                                                # No link on active page!
      'caption' => 'Paper copy',
    };
  }
  return;
}

1;

__END__

h3. Currently under development

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

