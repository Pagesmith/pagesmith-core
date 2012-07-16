package Pagesmith::Form::Element::Pubmed;
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

sub _is_valid {
  my $self = shift;
  return $self->value =~ m{\A(SID_)?\d+\Z}mxs;
}

sub _render_readonly {
  my $self = shift;
  return q(--) unless $self->value;
  return sprintf '<%% References %d %%>', $self->value;
}
sub _render_widget {
  my $self = shift;
  my $html = $self->SUPER::_render_widget;
  $html .= sprintf '<%% References %s %%>', encode_entities( $self->value ) if $self->value;
  return $html;
}

sub required_string {
  my $self = shift;
  my $html = $self->SUPER::required_string;
     $html =~ s{\A<(\w+)}{<$1 class="pubmed_req"}mxs;
  return $html;
}
sub element_class {
  my $self = shift;
  $self->add_class( '_pubmed' );
  $self->add_class( 'short' );
  $self->add_layout( '_pubmed' );
  return;
}

1;
