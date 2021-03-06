package Pagesmith::Action::Form;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

## Handles submission of Form object
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

use base qw(Pagesmith::Action);
use HTML::Entities qw(encode_entities);
use Pagesmith::ConfigHash qw(can_name_space);
use List::MoreUtils qw(uniq);

use Const::Fast qw(const);
const my $MAX_POST => 20_971_520; ## 20M max upload!

## URL for this action is:
## http://www.mydomain.com/form/-0123456789012345678901(/action)
## http://www.mydomain.com/form/FormType(/action)/ID <- if editing

sub configure_apr {
  my $self = shift;
  return $self->apr( { 'POST_MAX' => $MAX_POST } );
}

sub run {
  my $self = shift;
  $self->configure_apr;
  my $form_code   = $self->next_path_info;
  my $form_object;

  $self->no_qr();

  if( $form_code =~ m{\A-([-\w]{22})\Z}mxs ) { ## We need to get the form edit option!
    ## We are in the middle of an edit....
    my $form_id = $1;
    $form_object  = $self->form_by_code( $form_id );
    unless( $form_object ) {
      my $redirect_url = $self->cache( 'variable', "form|$form_id" )->get;
      return $self->redirect( $redirect_url ) if $redirect_url;
      return $self->wrap( 'Form error', "\n<p>\n  Do not recognise reference\n</p>" )->ok ;
    }
    my $msg = $form_object->cant_edit;                  ## See if the user can edit this stage!
    $form_object->set_stage_by_name( $msg ) if $msg;    ## CAN'T!
  } else { # Code is actually type....
    ## We need to create a new object!
    my $form_type;
    if( $form_code eq 'Generic' ) {
      my $generic_type = $self->next_path_info;
      $form_type    = "Generic - $generic_type";
      $form_object  = $self->generic_form( $generic_type, $self->next_path_info );
    } else {
      $form_type    = $form_code;
      my $module_name = $self->safe_module_name( $form_type );
      if( $module_name =~ m{\A([[:lower:]]+)::}mxis && ! can_name_space( $1 ) ) {
        return $self->wrap(
          'Form error',
          sprintf q(<p>Unable to generate form object of type '%s'</p>),
            encode_entities( $form_type ),
        )->ok;
      }
      $form_object  = $self->form( $module_name, $self->next_path_info ); ## This is the ID!
      $form_object->update_from_apr( $self->apr ) if $form_object->option( 'update_on_create' );
    }
    return $self->wrap( 'Form error',
      sprintf q(<p>Unable to generate form object of type '%s'</p>),
      encode_entities( $form_type ) )->ok unless $form_object; ## We can't create a new object!
    return $self->redirect( $form_object->action_url_get ) if $form_object->code; ## This has a forced code so actually just redirect!

    my $msg = $form_object->cant_create;                ## See if the user can edit this stage!
    $form_object->set_stage_by_name( $msg ) if $msg;    ## CAN'T
  }

  if( $form_object->secure && $self->r->headers_in->{'X-is-ssl'} ne '1' ) {
    return $self->redirect( $form_object->action_url_get );
  }

  $form_object->form_config->set_option( 'is_action', 1 ); ## Required so page can get wrapped later!
  $self->{'form_object'} = $form_object;

  $self->set_navigation_path( $form_object->option( 'navigation_path' ) );
  return $self->run_view  if $form_object->is_completed;
  return $self->r->method eq 'POST' ? $self->run_post : $self->run_get;
}

sub form_object {
  my $self = shift;
  return $self->{'form_object'};
}

sub dump_params {
  my $self = shift;
  my %param_hash = map { ( $_ => $self->param( $_ ) ) } $self->param;
  return $self;
}

sub run_post {
#@return (int) response code
## Either exectues _view OR redirects!
  my $self = shift;
  return $self->run_previous if $self->param( 'previous' );
  foreach my $id ( 0 .. ($self->form_object->n_stages - 1) ) {
    return $self->run_goto( $id ) if defined $self->param( "goto_$id" );
  }
  return $self->run_cancel   if $self->param( 'cancel' );
  return $self->run_next;
}

sub run_get {
#@return (int) response code
## Either exectues _view OR redirects!
  my $self = shift;
  $self->form_object->validate;
  return $self->run_view_paper if $self->param( 'paper' );
  foreach my $id ( 0 .. ($self->form_object->n_stages - 1) ) {
    return $self->run_goto( $id ) if defined $self->param( "goto_$id" );
  }
  return $self->run_jumbo      if $self->param( 'jumbo' );
  if( $self->form_object->stage_object->is_type( 'Redirect' ) ) {
    my $redirect_url = $self->form_object->on_redirect( $self->form_object->stage_object );
    return $self->redirect( $redirect_url ) if $redirect_url;
  }
  return $self->run_view;
}

sub run_cancel {
#@return (int) response code
## Redirects!
  my $self = shift;

  ## If we cancel where do we go!
  my $url;
  $url = $self->form_object->on_cancel( $self->form_object->stage_object )
    if $self->form_object->can('on_cancel');
  $url = $self->form_object->attribute( 'ref' ) || $self->base_url( $self->r ).q(/) unless $url;
  $self->form_object->destroy_object;
  return $self->redirect( $url );
}

sub run_previous {
#@return (int) response code
## Redirects!
  my $self = shift;

  return $self->run_view unless $self->form_object->code;   ## No object!      yarg!
  return $self->run_view unless $self->form_object->stage;  ## On first stage! yarg!

  $self->form_object->update_from_apr( $self->apr );    ## Update object from APR
  $self->form_object->validate;                         ## Get valid status of next pages...
  $self->form_object->goto_previous_stage;              ## Goto previous stage
  $self->form_object->store;
  return $self->redirect( $self->form_object->action_url_get );
}

sub run_next {
#@return (int) response code
## Either exectues _view OR redirects!
  my $self = shift;
  if( $self->r->method eq 'POST' ) {
    $self->form_object->update_from_apr( $self->apr );    ## Update object from APR
    $self->form_object->validate;                         ## Get valid status of next pages...
  }

  if( $self->form_object->stage_object->is_type( 'Confirmation' ) ) {
    ## Current stage is a confirmation stage.... so we
    my $confirmation_succeeded =  $self->form_object->on_confirmation( $self->form_object->stage_object );

    if( ! $confirmation_succeeded ) {
      # $self->push_messages( confirmation_failed! );
      ## We will need to push a message here! <- these will be returned from on_confirmation!
      return $self->redirect( $self->form_object->action_url_get );
    } else {
      ## This performs whatever confirmation stage is required...
      $self->form_object->goto_next_stage;
    }
  } else {
    $self->form_object->goto_next_stage;                  ## Goto next stage
  }

  if( $self->form_object->stage_object->is_type( 'Redirect' ) ) {
    my $redirect_url = $self->form_object->on_redirect( $self->form_object->stage_object );
    return $self->redirect( $redirect_url ) if $redirect_url;
  }
  $self->form_object->store;
  return $self->redirect( $self->form_object->action_url_get );
}

sub run_goto {
#@return (int) response code
## Redirects!
  my( $self, $id ) = @_;
  if( $self->form_object->on_goto( $self->form_object->stage_object, $id ) ) {
    $self->form_object->goto_stage( $id )->store;                  ## Goto next stage
    return $self->redirect( $self->form_object->action_url_get );
  }
  return $self->_view( $self->form_object->render );
}

sub run_view {
#@return (int) response code
## Either exectues _view OR redirects!
  my $self = shift;
  if( $self->form_object->stage_object->is_type( 'Confirmation' ) &&
    ! $self->form_object->stage_object->sections ) {
    return $self->run_next;
  }
  if( $self->form_object->stage_object->isa( 'Pagesmith::Form::Stage::Error' ) ) {
    $self->form_object->on_error( $self->form_object->stage_object );
  }
  return $self->_view( $self->form_object->render );
}

sub run_jumbo {
#@return (int) response code
## Runs "view"!
  my $self = shift;
  $self->form_object->validate_pages; ## This could reset the stage
  return $self->_view( $self->form_object->render_as_one );
}

sub run_view_paper {
#@return (int) response code
## Runs "view"
  my $self = shift;
#  $self->form_object->validate_pages; ## This could reset the stage
  return $self->_view( $self->form_object->render_paper );
}

sub _view {
#@return (int) response code
  my( $self, $html ) = @_;
  return $self->wrap_no_heading( $self->form_object->title, $html )->ok;
}

1;
