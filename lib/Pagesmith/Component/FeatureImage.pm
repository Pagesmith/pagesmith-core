package Pagesmith::Component::FeatureImage;

## Component
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

use base qw(Pagesmith::Component::Image);

use HTML::Entities qw(encode_entities);    ## HTML entity escaping

sub execute {
  my $self = shift;
  my ( $img, $cap ) = $self->pars;
  my $credit = $self->_credit( $self->option('credit') || q() );

  my $extra_class = q();
  $extra_class .= ' class="' . encode_entities( $self->option('class') ) . q(") if $self->option('class');
  if ( $self->option('popup') ) {
    return
      sprintf
'<div id="featureR"><div%s style="background-image:url(%s)"></div><p><a href="%s" class="thickbox" title="%s"><img alt="Enlarge this image" src="/core/gfx/blank.gif" /></a>[%s]</p></div>',
      $extra_class,
      encode_entities($img),
      encode_entities($img),
      encode_entities( $cap || $img ),
      $credit;
  } else {
    return sprintf '<div id="featureR"><div%s style="background-image:url(%s)"></div><p>[%s]</p></div>',
      $extra_class,
      encode_entities($img),
      $credit;
  }
}

1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

