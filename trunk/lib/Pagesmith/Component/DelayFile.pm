package Pagesmith::Component::DelayFile;

## Including a file!
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

sub define_options {
  my $self = shift;
  return (
    $self->SUPER::define_options,
    { 'code' => 'sleep', 'defn' => '=i', 'default' => 1, 'description' => 'Length of time to delay response' },
  );
}

sub usage {
  my $self = shift;
  my $usage = $self->SUPER::usage;
  $usage->{'description'} = 'Load a file (via ajax) with a slightly sleep';
  push @{$usage->{'notes'}}, 'DO NOT USE IN ANGER', 'This is really only designed as a demo module to demonstrate ajax methods!';
  return $usage;
}

sub execute {
  my $self = shift;
  sleep $self->option('sleep', 1);
  return $self->SUPER::execute;
}

1;

__END__

<% DelayFile
  -ajax
  -parse
  -delay n
  Filename
%>

h3. Purpose

Include a file within the page

h3. Options

* ajax - Delay loading via AJAX

* parse - Run file back through the directive compiler, so directives in the include will get parsed

h3. Notes

* If file starts with "/" then file is relative to docroot o/w relative to "page"

