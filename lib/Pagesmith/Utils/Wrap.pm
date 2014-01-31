package Pagesmith::Utils::Wrap;

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

use Text::WrapI18N ();

use Const::Fast qw(const);
const my $LINE_LENGTH => 72;

sub new {
  my ($class, $first, $next ) =@_;
  my $self  = {
    'first_header' => $first||q(),
    'next_header'  => $next||q(),
    'columns'      => $LINE_LENGTH,
    'huge'         => 'overflow',
    'tab_stop'     => 2,
    'separator'    => "\r\n",
  };
  bless $self, $class;
  return $self;
}

sub set_tab_stop {
  my( $self, $val ) = @_;
  $self->{'tab_stop'} = $val;
  return $self;
}

sub set_separator {
  my( $self, $val ) = @_;
  $self->{'separator'} = $val;
  return $self;
}

sub set_huge {
  my( $self, $val ) = @_;
  $self->{'huge'} = $val;
  return $self;
}

sub set_columns {
  my( $self, $val ) = @_;
  $self->{'columns'} = $val;
  return $self;
}

sub set_first_header {
  my( $self, $val ) = @_;
  $self->{'first_header'} = $val;
  return $self;
}

sub set_next_header {
  my( $self, $val ) = @_;
  $self->{'next_header'} = $val;
  return $self;
}

sub set_headers {
  my ( $self, $first, $next ) = @_;
  $next = $first unless defined $next;
  return $self->set_first_header( $first )->set_next_header( $next );
}

sub reset_headers {
  my $self = shift;
  return $self->set_first_header( q() )->set_next_header( q() );
}

sub wrap {
  my ( $self, @text ) = @_;
  ## no critic (PackageVars)
  local $Text::WrapI18N::columns   = $self->{'columns'};
  local $Text::WrapI18N::huge      = $self->{'huge'};
  local $Text::WrapI18N::tabstop   = $self->{'tab_stop'};
  local $Text::WrapI18N::separator = $self->{'separator'};
  ## use critic
  return Text::WrapI18N::wrap( $self->{'first_header'}, $self->{'next_header'}, @text );
}

1;
