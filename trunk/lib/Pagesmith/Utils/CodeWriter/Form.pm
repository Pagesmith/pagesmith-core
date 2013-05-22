package Pagesmith::Utils::CodeWriter::Form;

## Package to write packages etc!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Mon, 11 Feb 2013
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Utils::CodeWriter);

sub base_class {
  my $self = shift;
  my $filename = sprintf '%s/MyForm%s.pm',$self->base_path,$self->ns_path;

## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::MyForm::%1$s;

## Base form for namespace %1$s
%2$s

use base qw(Pagesmith::MyForm Pagesmith::Support::%1$s);

1;
),
    $self->namespace,           ## %1$s
    $self->boilerplate,         ## %2$s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

## no critic (ExcessComplexity)
sub admin {
  my ($self,$type) = @_;
  my $filename = sprintf '%s/MyForm%s/Admin/%s.pm',$self->base_path,$self->ns_path, $self->fp( $type );

  my $conf = $self->conf('objects',$type);
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $init_form_elements = q();
  unless( $conf->{'properties'}[0]{'type'} eq 'section' ) {
    $init_form_elements = sprintf "

    \$self->add_stage('$type');
    \$self->add_section( 'Administration of $type objects' );
    \$self->set_next_text( 'Create' );";
  }
  my $populate_object_code = q();
  my $update_object_code   = q();
  my $create_object_code   = q();
  my $max_prop_length      = 0;
  foreach my $prop ( @{$conf->{'properties'}} ) {
    next unless exists $prop->{'colname'};
    $max_prop_length = length $prop->{'colname'} if length $prop->{'colname'} > $max_prop_length;
  }
  $max_prop_length = - $max_prop_length - 2;
  foreach my $prop ( @{$conf->{'properties'}} ) {
    $init_form_elements .= "\n";
    if( $prop->{'type'} eq 'section' ) {
      if( exists $prop->{'stage_name'} ) {
        $init_form_elements .= sprintf q(
  $self->add_stage( '%s' );), $prop->{'stage_name'};
      }
      $init_form_elements .= sprintf q(
    $self->add_section( '%s' )), $prop->{'code'};
      $init_form_elements .= sprintf q(
      ->set_next( '%s' )), $self->addslash($prop->{'next'}) if exists $prop->{'next'};
      $init_form_elements .= sprintf q(
      ->set_caption( '%s' )), $self->addslash($prop->{'caption'}) if exists $prop->{'caption'};
      $init_form_elements .= sprintf q(
      ->set_notes( '%s' )), $self->addslash($prop->{'notes'}) if exists $prop->{'notes'};
      $init_form_elements .= q(;);
      next;
    }
    if( exists $prop->{'unique'} && $prop->{'unique'} eq 'uid' ) {
      $init_form_elements .= sprintf q(
      $self->add('Hidden','%s')
         ->set_optional;), $prop->{'colname'}||$prop->{'code'};
      next;
    }
    if( $prop->{'multiple'} ) {
      $populate_object_code .= sprintf q(
  $self->element( '%*s )->set_obj_data( [$self->object->get_%*s );),
        $max_prop_length, "$prop->{'colname'}'",
        $max_prop_length, "$prop->{'colname'}s]",
        ;
      $update_object_code   .= sprintf q[
  $self->object->set_%*s $self->element( '%*s )->multi_values );],
        $max_prop_length, "$prop->{'colname'}s(",
        $max_prop_length, "$prop->{'colname'}'",
        ;
      $create_object_code   .= sprintf q[
  $new_obj->set_%*s $self->element( '%*s )->multi_values );],
        $max_prop_length, "$prop->{'colname'}s(",
        $max_prop_length, "$prop->{'colname'}'",
        ;
    } else {
      $populate_object_code .= sprintf q(
  $self->element( '%*s )->set_obj_data( [$self->object->get_%*s );),
        $max_prop_length, "$prop->{'colname'}'",
        $max_prop_length, "$prop->{'colname'}]",
        ;
      $update_object_code   .= sprintf q[
  $self->object->set_%*s $self->element( '%*s )->scalar_value );],
        $max_prop_length, "$prop->{'colname'}(",
        $max_prop_length, "$prop->{'colname'}'",
        ;
      $create_object_code   .= sprintf q[
  $new_obj->set_%*s $self->element( '%*s )->scalar_value );],
        $max_prop_length, "$prop->{'colname'}(",
        $max_prop_length, "$prop->{'colname'}'",
        ;
    }
    $init_form_elements .= sprintf q(
      $self->add('%s','%s')
        ->set_caption( '%s' )),
      $prop->{'type'},
      $prop->{'colname'}||$prop->{'code'},
      $self->addslash( $prop->{'caption'}||$self->hr( $prop->{'colname'}||$prop->{'code'}) );
    if( exists $prop->{'multiple'} && $prop->{'multiple'} ) {
      $init_form_elements .= q(
        ->set_multiple);
      if( $prop->{'type'} ne 'DropDown' ) {
        $prop->{'size'} ||= 'medium';
      }
    }
    if( exists $prop->{'size'} ) {
      $init_form_elements .= sprintf q(
        ->add_class('%s')), $prop->{'size'};
    }
    if( exists $prop->{'optional'} && $prop->{'optional'} ) {
      $init_form_elements .= sprintf q(
        ->set_optional);
    }
    $init_form_elements .= sprintf q(
        ->set_notes( '%s' )), $self->addslash($prop->{'notes'}) if exists $prop->{'notes'};

    if( $prop->{'type'} eq 'DropDown' ) {
      if( exists $prop->{'multiple'}  && $prop->{'multiple'} ||
          exists $prop->{'firstline'} && $prop->{'firstline'} ||
          exists $prop->{'optional'}  && $prop->{'optional'}
        ) {
        $init_form_elements .= sprintf q(
          ->set_firstline(q(%s))), exists $prop->{'firstline'} ? $prop->{'firstline'} : q(==);
      }
      if( exists $prop->{'values'} ) {
        $init_form_elements .= sprintf q(
          ->set_values( Pagesmith::Object::%s::%s->dropdown_values_%s )),
          $self->namespace, $type, $prop->{'code'}
          ;
      } elsif( exists $prop->{'lookup'} ) {
        ## We need to add code here to get the SQL back ...

      }
    }
    $init_form_elements .= q(;);
  }
  my $perl = sprintf q(package Pagesmith::MyForm::%1$s::Admin::%2$s;

## Admininstration form for objects of type %2$s
## in namespace %1$s
%3$s

use base qw(Pagesmith::MyForm::%1$s);
use Pagesmith::Adaptor::%1$s::%2$s;
use Pagesmith::Object::%1$s::%2$s;

sub fetch_object {
  my $self = shift;##
  my $db_obj        = $self->adaptor( '%2$s' )->fetch_%8$s( $self->{'object_id'} );
  $self->{'object'} = $db_obj if $db_obj;
  return $db_obj;
}

sub populate_object_values {
  my $self = shift;
  return $self unless $self->object && ref $self->object;
%4$s
  return $self;
}

sub update_object {
  my $self = shift;
  ## Copy form values back to object...
%5$s
  $self->object->store;
  return 1;
}

sub create_object {
  my $self = shift;
  ## Creates new object with values from form...
  my $new_obj = $self->adaptor( '%2$s' )->create;
%6$s
  return unless $new_obj->store();
  $self->set_object( $new_obj )->set_object_id( $new_obj->uid );
  return 1;
}

sub initialize_form {
  my $self = shift;

  ## Set up the form...
  ## no critic (LongChainsOfMethodCalls)
  $self->set_title( '%2$s' )
       ->force_form_code
       ->add_attribute( 'id',     '%2$s' )
       ->add_attribute( 'method', 'post' )
       ->add_class(          'form',     'check' )          # Javascript validation is enabled
       ->add_class(          'section',  'panel' )          # Form sections are wrapped in panels
       ->add_form_attribute( 'method',   'post' )
       ->set_option(         'validate_before_next' )
       ->set_option(         'no_reset' )
       ->add_class(          'progress', 'panel' )
       ;

## Now add the elements%7$s

  ## use critic

  $self->add_confirmation_stage( 'please_confirm_details' );
    $self->add_section( 'please_confirm_details' );
      $self->add( { 'type' => 'Information', 'caption' => 'Please confirm the details below and press next to update object' } );

    $self->add_readonly_section;

    $self->add_section( 'information' );

      $self->add( { 'type' => 'Information', 'caption' => 'Press "confirm" to update object' } );

  $self->add_final_stage( 'thank_you' );

    $self->add_raw_section( '<p>The object has been updated</p>', 'Thank you' );

    $self->add_readonly_section;

  $self->add_error_stage( 'not_logged_in' );

    $self->add_raw_section( '<%% File /core/inc/forms/no_user.inc %%>' );

  $self->add_error_stage( 'no_permission'  );

    $self->add_raw_section( '<%% File /core/inc/forms/no_permission.inc %%>' );

  return $self;
}

1;
),
    $self->namespace,           ## %1$s
    $type,                      ## %2$s
    $self->boilerplate,         ## %3$s
    $populate_object_code,      ## %4$s
    $update_object_code,        ## %5$s
    $create_object_code,        ## %6$s
    $init_form_elements,        ## %7$s
    $self->ky($type),           ## %8$s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}
## use critic

1;

