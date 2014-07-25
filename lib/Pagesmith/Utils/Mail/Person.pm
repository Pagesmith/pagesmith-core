package Pagesmith::Utils::Mail::Person;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

## Email person - so we can easily format header!
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
use Encode qw(encode);

my $this_domain;

sub new {
  my( $class, $email, $name ) = @_;
  my $self = {
    'name'  => $name,
    'email' => $email,
  };
  bless $self, $class;
  return $self;
}

sub name {
  my $self = shift;
  return $self->{'name'};
}

sub email {
  my $self = shift;
  return $self->{'email'} =~ m{@}mxs ? $self->{'email'} : $self->{'email'}.q(@).$self->this_domain;
}

sub this_domain {
  my $self = shift;
  return $this_domain || q(localhost.localdomain);
}

sub set_this_domain {
  my ( $self, $domain ) = @_;
  $this_domain = $domain;
  return $self;
}

sub format_email {
  my $self = shift;
  return $self->safe_email_address( $self->{'email'} ) unless $self->{'name'};
  return sprintf q(%s <%s>), encode( 'MIME-Header', $self->{'name'} ), $self->safe_email_address( $self->{'email'} );
}

sub safe_email_address {
  my ( $self, $email ) = @_;
  if( $email =~ m{\A(.*)@(.*)}mxs ) {
    my($local,$domain) = ($1,$2);
    $local =~ s{(["\\])}{\\$1}mxsg;
    $local = qq("$local") if $local =~ m{["(),:;<>@\[\\\]]}mxs;
    return sprintf '%s@%s', $local, $domain;
  }
  return sprintf '%s@%s', $email, $self->this_domain;
}

1;
