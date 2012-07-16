package Pagesmith::Form::ElementTmp::RadioButton;

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

use base qw(Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

sub new {
  my( $class, %params ) = @_;
  my $self = $class->SUPER::new(
    %params,
  );
  $self->{'checked'}  = $params{'checked'};
  $self->{'disabled'} = $params{'disabled'};
  return $self;
}

sub checked {
  my $self = shift;
  return $self->{'checked'};
}
sub disabled {
  my $self = shift;
  return $self->{'disabled'};
}

sub render {
  my $self = shift;

  return sprintf
    qq(<tr>\n  <th><label class="label-radio"></th>\n  <td><input type="radio" name="%s" id="%s" value="%s" class="input-radio"%s%s/> %s %s</label></td>\n</tr>),
    encode_entities( $self->name ),
    encode_entities( $self->id ),
    $self->value || 'yes',
    $self->checked ? ' checked="checked" ' : q(),
    $self->disabled ? ' disabled="disabled" ' : q(),
    encode_entities( $self->label ),
    $self->notes
  ;
}

sub validate {
  return 1;
}


1;
