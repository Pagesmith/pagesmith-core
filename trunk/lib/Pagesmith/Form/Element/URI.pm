package Pagesmith::Form::Element::URI;
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

use base qw( Pagesmith::Form::Element::String );

use HTML::Entities qw(encode_entities);

sub init {
  my $self = shift;
  $self->{'fetch_title'} = $self->{'_options'}{'fetch_title'} || 1;
  return;
}

sub fetch_title {
  my $self = shift;
  return $self->{'fetch_title'};
}

sub set_fetch_title {
  my $self = shift;
  $self->{'fetch_title'} = 1;
  return $self;
}

sub clear_fetch_title {
  my $self = shift;
  $self->{'fetch_title'} = 0;
  return $self;
}

sub validate {
  my $self = shift;
  return $self->set_valid if $self->value =~ m{\A(?:https?|ftp)://\w.*\Z}mxs;
  return $self->set_invalid;
}

sub render_widget {
  my $self = shift;
  my $return = $self->SUPER::render_widget();
  $return .= sprintf '<p><%% Link -ajax -get_title %s %%></p>', encode_entities( $self->value )
    if $self->value && $self->value=~m{\Ahttp}mxs && $self->{'fetch_title'};
  return $return;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_uri'.($self->{'fetch_title'}?'_fetch_title':q()) );
  return;
}
1;
