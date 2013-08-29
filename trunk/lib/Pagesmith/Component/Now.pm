package Pagesmith::Component::Now;

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

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'date_format', 'defn' => '=s', 'default' => '%A %o %B',
      'description' => 'Date format string' },
    { 'code' => 'time_format','defn' => '=s',  'default' => '%l.%M%P',
      'description' => 'Time format string' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(),
    'description' => 'Display date and time',
    'notes'       => [
      '{name} name of module',
    ],
  };
}

sub execute {
  my $self = shift;
  return sprintf '<div class="panel"><p>%s</p></div>',
    time2str( 'It is '.$self->option('date_format').' at '.$self->option('time_format'), time );
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

