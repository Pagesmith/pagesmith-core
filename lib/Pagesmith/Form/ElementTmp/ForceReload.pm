package Pagesmith::Form::ElementTmp::ForceReload;

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

sub render {
  my $self = shift;
  return '<div class="modal_reload">This window will try and reload when closed</div>';
}

1;
