package Pagesmith::Component::Param;

## Insert a "inpur param" into the page
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

use base qw(Pagesmith::Component);

use URI::Escape qw(uri_escape_utf8);
use HTML::Entities qw(encode_entities);    ## HTML entity escaping

use Pagesmith::Core qw(fullescape);

sub execute {
  my $self = shift;
  my ( $variable, $default ) = $self->pars;

  my $val = $self->page->apr->param($variable);
  $val = $default unless defined $val;

  $val =
      $self->option('u') ? ( $self->option('f') ? fullescape($val) : uri_escape_utf8($val) )
    : $self->option('r') ? $val
    : $self->option('f') ? encode_entities( $val, q(^~) )
    :                      encode_entities( $val );
  return $val;
}
1;

__END__

<% Param
  -(u|r|f)?
  parameter
  default_value
%>

h3. Purpose

Include the value of a cgi

h3. Options

* u - URL escape the parameters

* r - RAW do no encoding - here be dragons

* f - Full encode all characters as numeric entities

h3. Notes

* default (no switches) is to perform entity encoding
