package Pagesmith::Utils::CodeWriter::Object;

## Package to write packages etc!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Mon, 11 Feb 2013
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Utils::CodeWriter);

sub base_class {
  my $self = shift;
  my $filename = sprintf '%s/Object%s.pm',$self->base_path,$self->ns_path;

## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::Object::%1$s;

## Base class for objects in %1$s namespace
%2$s
sub init {
  my( $self, $hashref ) = @_;
  $self->{'obj'} = {%%{$hashref}};
  return;
}

sub type {
  my $self = shift;
  my ( $type ) = (ref $self) =~ m{([^:]+)\Z}mxsg;
  return $type;
}

sub get_other_adaptor {
  my( $self, $type ) = @_;
  return $self->adaptor->get_other_adaptor( $type );
}

1;
),
    $self->namespace,    ## %1$
    $self->boilerplate,  ## %2$
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

sub create {
  my( $self, $type ) = @_;
  my $filename = sprintf '%s/Object%s/%s.pm',$self->base_path,$self->ns_path, $self->fp( $type );
  my $conf = $self->conf('objects',$type);

## Firstly the standard property setters!
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $lookup_constants = q();
  my $property_accessors;

  foreach my $prop_ref ( @{ $conf->{'properties'}||[]} ) {
    next if $prop_ref->{'type'} eq 'section';
    my $constraint = q();
    my $code = $prop_ref->{'colname'}||$prop_ref->{'code'};
    if( $prop_ref->{'type'} eq 'DropDown' ) {
      my %valid_values = map { ref $_ ? ( $_->[0] => $_->[1] ) : ( $_ => $_ ) } @{$prop_ref->{'values'}};

      $lookup_constants .= sprintf '

const my $ORDERED_%2$s => %3$s;
const my $LOOKUP_%2$s => %4$s;
sub dropdown_values_%1$s {
  return $ORDERED_%2$s;
}',
        $code,
        uc $code,
        $self->raw_dumper( $prop_ref->{'values'} ),
        $self->raw_dumper( \%valid_values );
      $constraint = sprintf q(
  unless( exists $LOOKUP_%2$s->{$value} ) {
    warn "Trying to set invalid value for '%1$s'\n";
    return $self;
  }), $code, uc $code;
    } elsif( $prop_ref->{'type'} =~ m{\APos}mxs ) {
      $constraint = sprintf q(
  if( $value <= 0 ) {
    warn "Trying to set non positive value for '%1$s'\n";
    return $self;
  }), $code;
    } elsif( $prop_ref->{'type'} =~ m{\ANonNeg}mxs ) {
      $constraint = sprintf q(
  if( $value < 0 ) {
    warn "Trying to set negative value for '%1$s'\n";
    return $self;
  }), $code;
    }
    $property_accessors .= sprintf q(

sub get_%1$s {
  my $self = shift;
  return $self->{'obj'}{'%2$s'};
}

sub set_%1$s {
  my ( $self, $value ) = @_;%3$s
  $self->{'obj'}{'%2$s'} = $value;
  return $self;
}), $prop_ref->{'code'}, $code, $constraint;
  }
## Now we have to add set/get for has "1" columns

## And for has "many" columns

## For "contains" columns

## Finally we have to add appropriate "Relationship requests"

  $lookup_constants =~ s{\s*^(?=;)}{}mxsg;
  $lookup_constants =~ s{'$}{',}mxsg;
  $lookup_constants = "## no critic (Quotes)$lookup_constants## use critic" if $lookup_constants =~ m{'\W*'}mxsg;

## Generete perl code...
  my $perl = sprintf q(package Pagesmith::Object::%1$s::%2$s;

## Class for %2$s objects in namespace %1$s.
%3$s
use base qw(Pagesmith::Object::%1$s);

## Definitions of lookup constants and methods exposing them to forms.

use Const::Fast qw(const);%6$s

## Get/sets for attributes of the %2$s

sub uid {
  my $self = shift;
  return $self->{'obj'}{'%4$s'};
}

## Property get/setters%5$s

## Has "1" get/setters

## Has "many" get/clear/add/remove code

## Contains getters

## Relationship getters!

## Store method

sub store {
  my $self = shift;
  return $self->adaptor->store;
}

## Other fetch functions!

1;

__END__

Purpose
-------

Object classes are the basis of the Pagesmith OO abstraction layer


),
    $self->namespace,                ## %1$
    $type,                           ## %2$
    $self->boilerplate,              ## %3$
    $conf->{'uid_property'}{'colname'}||$conf->{'uid_property'}{'code'}||'id',   ## %4$
    $property_accessors,             ## %5$
    $lookup_constants,               ## %6$
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

1;

