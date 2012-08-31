package Pagesmith::Component::Date;

## Return last modified date of file...
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

use Date::Format qw(time2str);

sub execute {
  my $self = shift;
  my $time = time;
  my $format = $self->option( 'format', '%a, %d %b %Y %H:%M %Z' );
  return time2str( $format, $time );
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

