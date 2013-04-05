package Pagesmith::Form::Element::AutoComplete;

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
use HTML::Entities qw(encode_entities);
use Const::Fast qw(const);

const my $DEFAULT_QUERY  => 'query';


use base qw( Pagesmith::Form::Element::String );

sub widget_type {
  return 'string';
}

sub init {
  my $self = shift;
  $self->{'url'}        = exists $self->{'_options'}{'url' }       ? $self->{'_options'}{'url'}        : $self->config->form_url."?autocomplete=$self->{'code'}";
  $self->{'query_name'} = exists $self->{'_options'}{'query_name'} ? $self->{'_options'}{'query_name'} : $self->{'code'} || $DEFAULT_QUERY;
  return $self;
}

sub set_url {
  my( $self, $url ) = @_;
  $self->{'url'} = $url;
  return $self;
}

sub set_query_name {
  my( $self, $url ) = @_;
  $self->{'query_name'} = $url;
  return $self;
}

sub element_class {
  my $self = shift;
  $self->add_class( 'auto_complete' );
  return;
}

sub extra_markup {
  my $self = shift;
  return sprintf ' title="%s=%s"', encode_entities( $self->{'query_name'}) , encode_entities( $self->{'url'} );
}

1;
