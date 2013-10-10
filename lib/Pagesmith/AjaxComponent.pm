package Pagesmith::AjaxComponent;

## Adds two standard Ajax definitions... to a module!
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

sub define_options {
  my $self = shift;
  return (
    $self->ajax_option
  );
}

sub ajax {
  my $self = shift;
  return $self->default_ajax;
}

1;
