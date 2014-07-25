package Pagesmith::Utils::FormObjectCreator;

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

## Tool for generating form objects either from the form object cache
## OR from the object type and object id...
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

use Pagesmith::ConfigHash qw(site_key);
use Pagesmith::Cache;
use Pagesmith::Form::Message;
use HTML::Entities qw(decode_entities);

sub new {
#@constructor
#@param (class)
#@return (self)
  my( $class, $r, $apr ) = @_;
  my     $self = { '_r' => $r, '_apr' => $apr };
  bless  $self, $class;
  return $self;
}

sub generic_form {
  my( $self, $r, $type, $code, $view_url ) = @_;
  ## This has been added but will not be implemented at the moment
  ## To stop crashing we need to have the function here!

#= for future development
# This function will grab an "XML/JSON/..." based configuration from the
# file system (or potentially from the config-cache) which defines the form
# elements - (and writes back to the Generic object pool?)
# At the moment this hasn't been thought through so we just return an
# error object

  return;
}

sub form_from_code {
  my( $self, $code ) = @_;
  my $ch = Pagesmith::Cache->new( 'form', $code, undef, site_key );
  my $fd = $ch->get();
  return unless $fd;                ## Cannot generate form object as code doesn't exist!
  utf8::downgrade($fd); ## no critic (CallsToUnexportedSubs)
  my $form_data = $self->json_decode( $fd );
  my $form_type = $form_data->{'type'};
  my $module    = "Pagesmith::MyForm::$form_type";
  return unless $self->dynamic_use( $module ); ## Cannot compile object of class $module
  $form_data->{ 'options' }      = { 'code' => $code };
  $form_data->{ 'cache_handle' } = $ch;
  $form_data->{ 'r' }            = $self->{'_r'};
  $form_data->{ 'apr' }          = $self->{'_apr'};
  ## Create the new object and return it!
  return $module->new( $form_data );
}

sub form_from_type {
  my( $self, $formtype, $id, $view_url ) = @_;
## May be a hack in here for generic forms that use a common module - but
## different configuration files (allowing forms to be created from XML files e.g.)

  my $module    = "Pagesmith::MyForm::$formtype";

  my $f = $self->dynamic_use( $module ); ## Cannot compile object of class $module
  unless( $f ) {
    warn $self->dynamic_use_failure( $module ),"\n";
    return;
  }
  ## Create the new object and return it!
  return $module->new({
    'r'         => $self->{'_r'},
    'apr'       => $self->{ '_apr' },
    'type'      => $formtype,
    'object_id' => $id,
    'view_url'  => $view_url||q(),
  });
}

1;
