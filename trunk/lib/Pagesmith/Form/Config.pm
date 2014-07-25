package Pagesmith::Form::Config;

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
use Carp qw(carp);

use HTML::Entities qw(encode_entities);

my %defaults = (
  'force_form_code'      => 0, # Doesn't produce a form code
  'validate_before_next' => 1, # Require validation on each page
  'progress_panel'       => 0, # No progress panel (useful for action based forms)
  'progress_navigation'  => 1, # Include navigation links in progress panel
  'confirmation_page'    => 1, # Include
  'navigation_path'      => q(/),
  'paper_link'           => 0, # Do not include
  'jumbo_link'           => 0, # Jumbo link
  'back_button'          => 1, # Show
  'cancel_button'        => 1, # Show
  'no_reset'             => 0, # Show
  'default_referer'      => q(/),
  'is_action'            => 0,
  'do_not_pass_ref'      => 0,
  'form_title'           => 'Form',
  'update_on_create'     => 0, # If set takes parameters from URL if form is initially created!
  'progress_caption'     => 'Form progress',
  'required_string'      => '<strong title="required field"><em>Required</em></strong>',
  'optional_string'      => '<em title="optional field">Optional</em>',
  'code'                 => undef,
);

my @class_groups = qw(wrapper form section element layout progress);

sub new {
  my( $class, $params ) = @_;
  my $self = {
    'form_url'        => $params->{'form_url'},
    'form_id'         => $params->{'form_id'} || 'form',
    'id'              => 'aaaa',
    'classes'         => {},
    'options'         => { %defaults, map { $_=>$params->{'options'}{$_} } sort keys %{$params->{'options'}||{}} },
  };
  foreach my $type ( @class_groups ) {
    $self->{'classes'}{$type} = { map { $_=>1 } @{$params->{'classes'}{$type} ||[]} };
  }
  bless $self, $class;
  return $self;
}

sub form_id {
  my $self = shift;
  return $self->{'form_id'};
}

sub form_url {
  my $self = shift;
  return $self->{'form_url'};
}

sub next_id {
  my $self = shift;
  return q(_).$self->{'id'}++;
}

sub set_option {
  my( $self, $key, $value ) = @_;
  if( exists $self->{'options'}{$key} ) {
    $self->{'options'}{$key} = $value;
  } else {
    carp "Unknown option $key (trying to set value $value)";
  }
  return $self;
}
sub option {
  my( $self, $key ) = @_;
  return unless exists $self->{'options'}{$key};
  return $self->{'options'}{$key};
}
#= Class manipulation functions
# Allows classes to be added to all sections (e.g. adding panel class to give
# them rounded borders etc) or all elements

sub classes {
  my( $self, $type ) = @_;
  return () unless exists $self->{'classes'}{$type};
  my @classes = sort keys %{ $self->{'classes'}{$type} };
  return @classes;
}

sub add_class {
#@param (self)
#@param (string) $type  type of class to store in the config!
#@param (string) $class CSS class to add to form
  my ( $self, $type, $class ) = @_;
  return $self unless exists $self->{'classes'}{$type};
  $self->{'classes'}{$type}{$class} = 1;
  return $self;
}

1;
