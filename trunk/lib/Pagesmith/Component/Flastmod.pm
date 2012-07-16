package Pagesmith::Component::Flastmod;

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

use base qw(Pagesmith::Component::File);
use File::Basename qw(basename);

use Date::Format qw(time2str);

sub execute {
  my $self = shift;
  my $fn = $self->_get_filename( $self->next_par || basename( $self->page->filename ) );
  return 'Unable to find file' unless $fn;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat $fn;
  my $format = $self->option( 'format', '%a, %d %b %Y %H:%M %Z' );
  return time2str( $format, $mtime );
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

