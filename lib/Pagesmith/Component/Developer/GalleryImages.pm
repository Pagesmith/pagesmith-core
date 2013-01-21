package Pagesmith::Component::Developer::GalleryImages;

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

use base qw(Pagesmith::Component);

use HTML::Entities qw(encode_entities);

sub usage {
  return {
    'parameters'  => q(None),
    'description' => q(Lists all images that are in galleries on the current page)
    'notes' => [ 'Galleries push thie information in the page store "gallery_images"'],
  };
}

sub execute {
  my $self = shift;

  my $href = $self->get_store('gallery_images');
  return unless $href;

  return '<ul>'. join (q(), map {
    qq(<li><a href="$_">$_</a></li>)
  } @{$href->{'images'}} ).'</ul>';
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
