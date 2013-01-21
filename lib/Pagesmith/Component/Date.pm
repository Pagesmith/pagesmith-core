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

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'zone',  'defn' => '=s',                                       'description' => 'Time zone' },
    { 'code' => 'format','defn' => '=s', 'default' => '%a, %d %b %Y %H:%M %Z', 'description' => 'Standard time2str date format' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(),
    'description' => 'Display the current time',
    'notes'       => [],
  };
}


sub execute_time {
  my ($self, $time ) = @_;
  return time2str( $self->option( 'format' ), $time, $self->option( 'zone' ) );
}

sub execute {
  my $self = shift;
  return $self->execute_time( time );
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

