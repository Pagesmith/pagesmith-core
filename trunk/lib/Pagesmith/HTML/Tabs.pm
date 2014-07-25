package Pagesmith::HTML::Tabs;

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

use HTML::Entities qw(encode_entities);
use Date::Format qw(time2str);
use Const::Fast qw(const);
use POSIX qw(mktime);
use URI::Escape qw(uri_escape_utf8);
use List::MoreUtils qw(uniq);

const my $TIME_FORMAT => '%H:%M';
const my $DATE_FORMAT => '%a, %d %b %Y';
const my $DOFF        => 1900;
const my $CENT        => 100;

sub new {
  my( $class, $options ) = @_;
  $options ||= {};
  my $self = {
    'options'       => $options,
    'tabs'          => [],
    'classes'       => [],
    'div_classes'   => [],
  };
  bless $self, $class;
  return $self;
}

sub add_div_classes {
  my( $self, @classes ) = @_;
  push @{$self->{'div_classes'}}, @classes;
  return $self;
}

sub add_classes {
  my( $self, @classes ) = @_;
  push @{$self->{'classes'}}, @classes;
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

sub add_tabs {
  my( $self, @tab_details ) = @_;
  $self->add_tab( @{$_} ) foreach @tab_details;
  return $self;
}

sub add_tab {
  my( $self, $key, $title, $html, $options ) = @_;
  $options ||= {};
  $options->{'no_heading'} ||= $self->option('no_heading');

  push @{$self->{'tabs'}}, {
    'key'   => $key,
    'title' => $title,
    'html'  => $html,
    'options' => $options,
  };
  return $self;
}

sub unshift_tab {
  my( $self, $key, $title, $html, $options ) = @_;
  $options ||= {};

  unshift @{$self->{'tabs'}}, {
    'key'   => $key,
    'title' => $title,
    'html'  => $html,
    'options' => $options,
  };
  return $self;
}

sub tab_type {
  my $self = shift;
  return $self->option('fake') ? 'fake-tabs' : 'tabs';
}

sub render_ul_block {
  my $self = shift;
  my @html;
  push @html, sprintf q(  <ul class="%s">), join q( ), $self->tab_type, @{$self->{'classes'}||[]};
  foreach my $entry ( @{$self->{'tabs'}} ) {
    my $extra = q();
    $extra .= sprintf ' class="%s"', encode_entities( $entry->{'options'}{'link_class'} ) if exists $entry->{'options'}{'link_class'};
    push @html, sprintf '    <li><a href="#%s"%s>%s</a></li>', encode_entities($entry->{'key'}), $extra, encode_entities($entry->{'title'});
  }
  push @html, q(  </ul>);
  return join qq(\n), @html;
}

sub render_div_block {
  my $self = shift;
  my @html;
  foreach my $entry ( @{$self->{'tabs'}} ) {
    my $html = q();
    unless( $entry->{'title'} eq q() || exists $entry->{'options'}{'no_heading'} && $entry->{'options'}{'no_heading'}) {
      if( exists $entry->{'options'}{'class'} && $entry->{'options'}{'class'}) {
        $html .= sprintf '<h3 class="%s">%s</h3>', $entry->{'options'}{'class'}, encode_entities( $entry->{'title'} );
      } else{
        $html .= sprintf '<h3>%s</h3>', encode_entities( $entry->{'title'} );
      }
    }
    $html .= $entry->{'html'};
    my @classes = @{ $self->{'div_classes'} || [] };
    if( exists $entry->{'options'}{'div_class'} ) {
      if( ref $entry->{'options'}{'div_class'} eq 'ARRAY' ) {
        push @classes, @{ $entry->{'options'}{'div_class'} };
      } else {
        push @classes, $entry->{'options'}{'div_class'};
      }
    }
    @classes = sort uniq @classes;
    my $div_class = q();
    $div_class = sprintf ' class="%s"', join q( ), @classes if @classes;

    push @html, sprintf '  <div id="%s"%s>%s</div>', encode_entities($entry->{'key'}), $div_class, $html;
  }
  return join qq(\n), @html;
}

sub render {
  my $self = shift;
  return $self->render_ul_block.$self->render_div_block;
}

1;
