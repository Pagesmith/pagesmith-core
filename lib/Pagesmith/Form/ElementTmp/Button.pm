package Pagesmith::Form::ElementTmp::Button;

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

use base qw( Pagesmith::Form::Element );

use HTML::Entities qw(encode_entities);

sub _init {
  return;
}
sub render {
  ## NB: this function is normally called from Form::render_buttons, which wraps the buttons in a TR tag
  my $self = shift;
  return sprintf
    '<input type="button" name="%s" value="%s" class="submit" style="margin-left:0.5em;margin-right:0.5em" />',
    encode_entities($self->name) || 'submit',
    encode_entities($self->value),
  ;
}
1;
