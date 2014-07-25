package Pagesmith::HTML::TwoCol;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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

## Class to render a table;
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

use base qw(Pagesmith::Support);

use Date::Format qw(time2str);
use Const::Fast qw(const);
use POSIX qw(mktime);
use URI::Escape qw(uri_escape_utf8);

const my $TIME_FORMAT => '%H:%M';
const my $DATE_FORMAT => '%a, %d %b %Y';
const my $DOFF        => 1900;
const my $CENT        => 100;

sub new {
  my( $class, $options ) = @_;
  $options ||= {};
  $options->{'hide_duplicate_keys'} = 1 unless exists $options->{'hide_duplicate_keys'};
  my $self = {
    'options'       => $options,
    'entries'       => [],
  };
  bless $self, $class;
  return $self;
}

## General option setting...
sub option {
  my( $self, $key ) = @_;
  return $self->{'options'}{$key};
}

sub clear_option {
  my( $self, $key ) = @_;
  delete $self->{'options'}{$key};
  return $self;
}

sub set_option {
  my( $self, $key, $value ) = @_;
  $self->{'options'}{$key} = $value;
  return $self;
}

sub no_of_entries {
  my $self = shift;
  return @{$self->{'entries'}};
}

sub add_entry_encode {
  my( $self, $caption, @entries) = @_;
  return $self->add_entry( $caption, map { ref $_ ? $_ : $self->encode( $_ ) } @entries );
}

sub add_entry_email {
  my( $self, $caption, $email, $default ) = @_;
  return $self->add_entry( $caption, $default||'&nbsp;' ) unless $email;
  return $self->add_entry( $caption, $self->safe_email( $email ) );
}

sub add_entry_url {
  my( $self, $caption, $url, $default, $length ) = @_;
  return $self->add_entry( $caption, $default||'&nbsp;' ) unless $url;
  return $self->add_entry( $caption, sprintf '<%% Link -get_title -length %d %s %%>',
    $length||0, $self->encode( $url ) );
}

sub add_entry {
  my( $self, $caption, @entries) = @_;
  my $options = {};
  $options = shift @entries if @entries && ref $entries[0] eq 'HASH';

  if( $self->option('hide_duplicate_keys') && @{$self->{'entries'}} && (
    $self->{'entries'}[-1]{'caption'} eq $caption || ! defined $caption
  ) ) {
    push @{ $self->{'entries'}[-1]{'values'} }, @entries if @{$self->{'entries'}};
    return $self;
  }
  push @{$self->{'entries'}}, { 'caption' => $caption, 'values' => \@entries, 'options' => $options };
  return $self;
}

sub entries {
  my $self = shift;
  return @{$self->{'entries'}||[]};
}

sub render {
  my $self = shift;
  return q() unless @{$self->{'entries'}};

  my @e = @{$self->{'entries'}};

  @e = grep { @{$_->{'values'}} } @e unless defined $self->option( 'keep_empty' );

  return q() unless @e;

  my @classes = ('twocol');
  push @classes, $self->option('class') if $self->option('class');
  my @html = (
    sprintf q(  <dl class="%s">), join q( ),@classes,
  );
  foreach my $entry ( @e ) {
    my $class = $entry->{'options'}{'class'} || $self->option('entry_class') || q();
    $class = sprintf ' class="%s"', $class if $class;
    push @html,       sprintf '    <dt%s>%s</dt>', $class, $entry->{'caption'};
    if( @{$entry->{'values'}} ) {
      push @html, map { sprintf '    <dd%s>%s</dd>', $class, $_ } @{ $entry->{'values'} };
    } else {
      push @html, sprintf '    <dd%s>%s</dd>', $class, $self->option( 'keep_empty' )||q();
    }
  }
  push @html, q(  </dl>);
  return join qq(\n), @html;
}

1;
