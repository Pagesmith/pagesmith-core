package Pagesmith::MyForm;

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

## All dynamically included forms have a name space of Pagesmith::MyForm, this is a protection
## against including the wrong type of module - MyForm defines a template for the page, to show
## where Introduction, Form and FormProgress are combined to produce the finalised layout for
## Action version of the form
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

use Crypt::CBC;

use base qw(Pagesmith::Form);

sub form_type {
  my $self = shift;
  return ref($self) =~ m{\APagesmith::MyForm::(.*)\Z}mxs ? $1 : undef;
}

sub set_no_progress {
  my( $self, $value ) = @_;
  $value = 1 unless defined $value;
  $self->{'no_progress'} = $value;
  return $self;
}
sub no_progress {
  my $self = shift;
  return exists $self->{'no_progress'} ? $self->{'no_progress'} : 0;
}

sub page_template {
#@return (string) template to indicate how to layout the page
  my $self = shift;
  ## no critic (ImplicitNewlines)

  return '
<% Introduction %>
<div id="main">
  <% Form %>
</div>
<div id="rhs">
  <% FormProgress %>
  <% Extra %>
</div>' unless $self->no_progress;
  return '
<% Introduction %>
<div id="main">
  <% Form %>
</div>
<div id="rhs">
  <% Extra %>
</div>' if $self->render_extra;
  return '
<% Introduction %>
<% Form %>';

  ## use critic
}

1;

### Email bits!

sub ip_useragent_details {
  my $self = shift;
  return join q(), map { sprintf "%20s : %s\n", $_, $self->object->$_ } qw(ip created_at useragent);
}

sub get_name {
  my $self;
  return 'Name';
}

sub get_email {
  my $self;
  return 'Email';
}

sub populate_generic_object_values {
  my $self = shift;

  return $self unless $self->object && ref $self->object;

  ## Copy values from object into form...
  my $cache = {};
  foreach my $code ( keys %{$self->all_elements} ) {
    my $value = $cache->{$code} ||= $self->object->$code;
    foreach my $el ( $self->elements($code) ) {
      $el->set_obj_data( $value );
    }
  }
  return $self;
}

sub fetch_generic_object {
  my $self = shift;
  ## Firstly lets see if it isn't a course code (but a saved referee)
  my $gen_obj = $self->adaptor->get( $self->object_id );
  if( $gen_obj ) {
    $self->set_object( $gen_obj );
  }
  return 1; ## Don't clear object_id so we can test it later!
}

sub default_store_and_send_email {
  my( $self, $flag ) = @_;
  $flag ||= q();
  my $object_data = {};

  ## Send out emails to the user and to the applications people!
  my $code = $self->code;
## Copy data into the object!
  $_->set_obj_data( $code ) foreach $self->elements( 'code' );

  foreach my $e_code ( keys %{$self->all_elements} ) {
    foreach my $e ( $self->elements( $e_code ) ) {
      $object_data->{ $e_code } = $e->value;
    }
  }
## If we have an object then we should update the object;
## otherwise - create a new object and store it
  if( $self->object ) {
    return unless $self->object->store;
  } else {
    my $generic_object = $self->adaptor->create({ 'objdata' => $object_data });
    return unless $generic_object->store();
    $self->set_object( $generic_object )->set_object_id( $code );
  }
## Now send email...
  $self->default_send_email;
## Mark object as dead and return id!
  $self->completed unless $flag eq 'do_not_complete';
  return $self->object->id;
}

sub default_send_email {
  my $self = shift;
  my @emails = $self->get_email_addresses;
  my $body   = $self->email_template;
  foreach my $email_ref ( @emails ) {
    $self->send_email( {
      'To'           => $email_ref->{'to'},
      'From'         => $email_ref->{'from'},
      'Return-Path'  => $email_ref->{'from'},
      'Subject'      => $self->header_encode( $email_ref->{'subject'} ),
      'X-Generator'  => $self->header_encode( 'Pagesmith: '.($email_ref->{'generator'}||'Form To Email') ),
      'Content-type' => 'text/plain; charset=UTF-8',
    }, $body );
  }
  return;
}

sub generic_footer {
  my $self = shift;
  return sprintf 'Sent by Pagesmith form: %s', ref $self;
}

1;
__END__
h1. Pagesmith::MyForm

Base class for the dynamically included forms
