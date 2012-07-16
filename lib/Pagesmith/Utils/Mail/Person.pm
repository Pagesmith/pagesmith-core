package Pagesmith::Utils::Mail::Person;

## Base class to add common functionality!
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

sub new {
  my( $class, $email, $name ) = @_;
  my $self = {
    'name'  => $name,
    'email' => $email,
  };
  bless $self, $class;
  return $self;
}

sub format_email {
  my $self = shift;
  return $self->{'email'} unless $self->{'name'};
  ( my $name = $self->{'name'} ) =~ s{["']}{\\\1}mxgs;
  $name =~ s{\s+}{ }mxgs;
  $name =~ s{\A\s+}{}mxs;
  $name =~ s{\s+\Z}{}mxs;

  return sprintf q("%s" <%s>), $name, $self->{'email'};
}

1;
