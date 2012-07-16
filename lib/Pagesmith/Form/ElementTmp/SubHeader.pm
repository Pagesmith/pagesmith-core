package Pagesmith::Form::ElementTmp::SubHeader;

###
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

sub is_input {
  my $self = shift;
  return 0;
}

sub new {
  my( $class, @pars ) =@_;
  return $class->SUPER::new( @pars, 'layout' => 'spanning' );
}

sub render {
  my $self = shift;
  return sprintf '<tr><td colspan="2" style="text-align:left"><h3>%s</h3></td></tr>',
    $self->value;
}

1;
