package Pagesmith::Form::SubmitButton;

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

use base qw(Pagesmith::Support);

use Carp;
use HTML::Entities qw(encode_entities);
use List::MoreUtils qw(any);

sub type {
  my $self = shift;
  return 'submit';
}

sub new {
  my ( $class, $form, $element_data ) = @_;

  my $id = $element_data->{'id'};
  my $code = $element_data->{'code'} || $element_data->{'id'};

  my $self = {
    'form_id'        => $form->form_config->form_id,
    'classes'        => {},
    'caption'        => exists $element_data->{'caption'} ? $element_data->{'caption'} : ucfirst $code,
    'title'          => $element_data->{'hint'},
    'code'           => $code,
  };
  bless $self, $class;

  while ( !$id ) {
    my $t_id = q(_) . $self->random_code;
    $id = $t_id unless any { $t_id eq $_->id } $form->buttons;
  }

  if( exists $element_data->{'class'} ) {
    if( ref $element_data->{'class'} eq 'ARRAY' ) {
      $self->add_class( $_ ) foreach @{$element_data->{'class'}};
    } else {
      $self->add_class( $element_data->{'class'} )
    }
  }

  if( exists $element_data->{'layout'} ) {
    if( ref $element_data->{'layout'} eq 'ARRAY' ) {
      $self->add_layout( $_ ) foreach @{$element_data->{'layout'}};
    } else {
      $self->add_layout( $element_data->{'layout'} )
    }
  }

  $self->set_id(   $id );
  return $self;
}

sub set_form_id {
  my( $self, $value ) = @_;
  $self->{'form_id'} = $value;
  return;
}

sub form_id {
  my $self = shift;
  return $self->{'form_id'};
}

sub set_id {
  my( $self, $value ) = @_;
  $self->{'id'} = $value;
  return;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub set_code {
  my( $self, $value ) = @_;
  $self->{'code'} = $value;
  return;
}

sub code {
  my $self = shift;
  return $self->{'code'};
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


#= Class manipulation functions...

sub classes {

#@param (self)
#@return (string+) list of classes
## Return the list of classes associated with the form!
  my $self = shift;
  my @classes = sort keys %{ $self->{'classes'} };
  return @classes;
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

  my ( $self, $class ) = @_;
  $self->{'classes'}{$class} = 1;
  return $self;
}

sub generate_id_string {
  my $self = shift;
  return encode_entities( join q(_), 'button', $self->form_id, $self->id );
}

sub element_class {
  return;
}


sub generate_class_string {
  my $self = shift;
  return join q( ), $self->classes;
}

sub render {
  my $self = shift;
  my $class_string = $self->generate_class_string;
  return sprintf '<input type="%s" class="%s" id="%s" name="%s" value="%s%s%s" %s/>',
    $self->type,
    $self->generate_class_string,
    $self->generate_id_string,
    $self->code,
    $self->code eq 'previous' ? '&laquo;' : q(),
    encode_entities( $self->caption ),
    $self->code eq 'next' ? '&raquo;' : q(),
    defined $self->{'title'} ? sprintf 'title="%s"', encode_entities($self->{'title'}) : q(),
    ;
}

1;
