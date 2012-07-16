package Pagesmith::Form::Element::PubmedList;
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

use base qw( Pagesmith::Form::Element::Text );
use HTML::Entities qw(encode_entities);

sub _is_valid {
  my $self = shift;
  return $self->value =~ m{\A\s*((?:SID_)?\d+\s+)*(?:SID_)?\d+\s*\Z}mxs;
}

sub _render_readonly {
  my $self = shift;
  return q(--) unless $self->value;
  return sprintf '<%% References %s %%>', encode_entities( $self->value );
}

sub _extra_information {
  my $self = shift;
  my $html = $self->SUPER::_extra_information;
  $html .= sprintf '<%% References %s %%>',encode_entities( $self->value ) if $self->value;
  return $html;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_pubmed_list' );
  $self->add_layout( '_pubmed' );
  return;
}
1;
