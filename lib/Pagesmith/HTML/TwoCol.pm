package Pagesmith::HTML::TwoCol;

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

use HTML::Entities qw(encode_entities);
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

sub add_entry {
  my( $self, $caption, @entries) = @_;
  my $options = {};
  $options = shift @entries if @entries && ref $entries[0] eq 'HASH';

  if( @{$self->{'entries'}} && (
    $self->{'entries'}[-1]{'caption'} eq $caption || ! defined $caption
  ) ) {
    push @{ $self->{'entries'}[-1]{'values'} }, @entries if @{$self->{'entries'}};
    return $self;
  }
  push @{$self->{'entries'}}, { 'caption' => $caption, 'values' => \@entries, 'options' => $options };
  return $self;
}

sub render {
  my $self = shift;
  return q() unless @{$self->{'entries'}};

  my @classes = ('twocol');
  push @classes, $self->option('class') if $self->option('class');
  my @html = (
    sprintf q(  <dl class="%s">), join q( ),@classes,
  );
  foreach my $entry ( @{$self->{'entries'}} ) {
    my $class = $entry->{'options'}{'class'} || $self->option('entry_class') || q();
    $class = sprintf ' class="%s"', $class if $class;
    push @html,       sprintf '    <dt%s>%s</dt>', $class, $entry->{'caption'};
    push @html, map { sprintf '    <dd%s>%s</dd>', $class, $_ } @{ $entry->{'values'} };
  }
  push @html, q(  </dl>);
  return join qq(\n), @html;
}

1;
