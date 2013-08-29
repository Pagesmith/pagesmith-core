package Pagesmith::Component::Developer::Test;

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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Component);
use HTML::Entities qw(encode_entities);

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(),
    'description' => 'Just a test module for options! - dumps the options/parameters...',
    'notes'       => [],
  };
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'ajax' },
    { 'code' => 'test',   'defn' => '=s',  'default' => 'def_value' },
    { 'code' => 'flag',   'defn' => q(),   'default' => 0, 'interleave' => 1 },
    { 'code' => 'other',  'defn' => q(!),  'interleave' => 1      },
    { 'code' => 'height', 'defn' => '=i',  'default' => 200, 'interleave' => 1  },
    { 'code' => 'width',  'defn' => ':i',  'default' => 300, 'interleave' => 1  },
    { 'code' => 'array',  'defn' => '=i@', 'default' => []   },
    { 'code' => 'hash',   'defn' => ':i%', 'default' => {}   },
  );
}

sub interleave_options {
  my $self = shift;
  return qw(flag other height width);
}

sub execute {
  my $self = shift;
  return $self->pre_dumper( { 'options' => $self->options, 'pars' => [$self->pars], 'pars_hash' => [$self->pars_hash] } );
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

