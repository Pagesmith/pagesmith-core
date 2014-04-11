package Pagesmith::MyForm::ObjectAdmin;

## Admininstration form for objects of type Series
## in namespace Sanger::AdvCourses

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Thu, 23 Jan 2014
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::MyForm);

sub admin_init {
  my $self = shift;
## no critic (LongChainsOfMethodCalls)
  $self
    ->set_option(          'validate_before_next' )
    ->set_option(          'no_reset' )
    ->set_no_progress
    ->add_attribute(       'id',       'admin_form' )
    ->add_attribute(       'method',   'post' )
    ->add_class(           'form',     'check' )          # Javascript validation is enabled
    ->add_class(           'section',  'panel' )          # Form sections are wrapped in panels
    ->add_form_attribute(  'method',   'post' )
    ->add_class(           'form',     'cancel_quietly' )
    ->set_title(           $self->object_type )
    ->add_stage(           $self->object_type );
## use critic
  $self->add_section( 'Administering '.$self->object_type );
  $self->set_next( $self->object_id ? 'Update' : 'Create' );
  return $self;
}

sub add_end_stages {
  my $self = shift;
  $self->add_redirect_stage( 'thank_you' );
  $self->add_error_stage( 'not_logged_in' );
    $self->add_raw_section( '<% File /core/inc/forms/no_user.inc %>' );
  $self->add_error_stage( 'no_permission'  );
    $self->add_raw_section( '<% File /core/inc/forms/no_permission.inc %>' );
  return $self;
}

## Security

sub cant_create {
  my $self = shift;
  return 'not_logged_in' unless $self->user->logged_in;
  return 'no_permission' unless $self->me && $self->me->is_admin;
  return;
}

sub cant_create_superadmin {
  my $self = shift;
  return 'not_logged_in' unless $self->user->logged_in;
  return 'no_permission' unless $self->me && $self->me->is_superadmin;
  return;
}


sub cant_edit {
  my $self = shift;
  return $self->cant_create;
}

## Getting object (using adaptor) and copying values to form!

sub fetch_object {
  my $self = shift;##
  my $fetch_method  = 'fetch_'.lc $self->object_type;
  my $o             = $self->adaptor( $self->object_type )->$fetch_method( $self->{'object_id'} );
  $self->{'object'} = $o if $o;
  return $o;
}

sub populate_object_values {
  my $self = shift;
  return $self unless $self->object && ref $self->object;
  foreach( $self->entry_names ){
    my $method = "get_$_";
    $self->element( $_ )->set_obj_data( [$self->object->$method] );
  }
  return $self;
}

## Getting information from form and writing it back to object

sub on_redirect {
  my $self = shift;
  my $flag = $self->object_id ? $self->update_object : $self->create_object;
  return $self->attribute( 'ref' );
}

sub update_object {
  my $self = shift;
  ## Copy form values back to object...
  foreach( $self->entry_names ){
    my $method = "set_$_";
    $self->object->$method( $self->element( $_ )->scalar_value );
  }
  $self->patch_object($self->object) if $self->can( 'patch_object' );
  $self->object->store;
  return 1;
}

sub create_object {
  my $self = shift;
  ## Creates new object with values from form...
  my $o = $self->adaptor( $self->object_type )->create;
  foreach( $self->entry_names ){
    my $method = "set_$_";
    $o->$method( $self->element( $_ )->scalar_value );
  }
  $self->patch_object($o) if $self->can( 'patch_object' );
  return unless $o->store();
  $self->set_object( $o )->set_object_id( $o->uid );
  return 1;
}

1;
