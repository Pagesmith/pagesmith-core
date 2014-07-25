package Pagesmith::Utils::CodeWriter::Object;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

use base qw(Pagesmith::Object);

sub init {
  my( $self, $hashref, $partial ) = @_;
  $self->{'obj'} = {%%{$hashref}};
  $self->flag_as_partial if defined $partial && $partial;
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

sub created_at {
  my $self = shift;
  return $self->{'obj'}{'created_at'};
}

sub set_created_at {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_at'} = $value;
  return $self;
}

sub created_by {
  my $self = shift;
  return $self->{'created_by'}||%3$s;
}

sub set_created_by {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_by'} = $value;
  return $self;
}

sub updated_at {
  my $self = shift;
  return $self->{'obj'}{'updated_at'};
}

sub updated_by {
  my $self = shift;
  return $self->{'obj'}{'updated_by'}||%3$s;
}

sub set_updated_at {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_at'} = $value;
  return $self;
}

sub set_updated_by {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_by'} = $value;
  return $self;
}

sub ip {
  my $self = shift;
  return $self->{'obj'}{'ip'};
}

sub set_ip {
  my( $self, $value ) = @_;
  $self->{'obj'}{'ip'} = $value;
  return $self;
}

sub useragent {
  my $self = shift;
  return $self->{'obj'}{'useragent'};
}

sub set_useragent {
  my( $self, $value ) = @_;
  $self->{'obj'}{'useragent'} = $value;
  return $self;
}

1;

__END__

Notes
=====

Base class for all objects - note we overwrite most of the audit functions
as we store the entries in {obj} rather than directly on the object...

),
    $self->namespace,    ## %1$
    $self->boilerplate,  ## %2$
    $self->user_audit_is_id ? 0 : 'q(--)', ## %3$
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

## no critic (ExcessComplexity DeepNests)
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
    if( $prop_ref->{'multiple'} ) {
      my $partial_clause = q();
      if( exists $prop_ref->{'tables'} ) {
        $partial_clause = sprintf q(
  return $self->{'obj'}{'partial_%2$s'} if exists $self->{'obj'}{'partial_%2$s'} &&
                                           !exists $self->{'obj'}{'%2$s'};),
          $prop_ref->{'code'}, $code;
      }
      $property_accessors .= sprintf q(

## Property: %1$s
## ----------%4$s

sub get_%1$ss {
  my $self = shift;
  my @ret = sort keys %%{$self->{'obj'}{'%2$s'}||{}};
  return @ret;
}

sub get_%1$s_string {
  my $self = shift;%5$s
  return join q(, ), $self->get_%1$s;
}

sub set_%1$ss {
  my ( $self, @values ) = @_;
  $self->clear_%1$ss
       ->add_%1$ss( @values );
  return $self;
}

sub add_%1$ss {
  my ( $self, @values ) = @_;
  $self->add_%1$s( $_ ) foreach @values;
  return $self;
}

sub add_%1$s {
  my ( $self, $value ) = @_;%3$s
  $self->{'obj'}{'%2$s'}{$value}=1;
  return $self;
}

sub remove_%1$s {
  my ( $self, $value ) = @_;
  return $self unless exists $self->{'obj'}{'%2$s'}{$value};
  delete $self->{'obj'}{'%2$s'}{$value};
  return $self;
}

sub remove_%1$ss {
  my ( $self, @values ) = @_;
  $self->remove_%1$s( $_ ) foreach @values;
  return $self;
}

sub clear_%1$ss {
  my ( $self, $value ) = @_;
  $self->{'obj'}{'%2$s'} = [];
  return $self;
}), $prop_ref->{'code'}, $code, $constraint, q(-) x length $prop_ref->{'code'},
    $partial_clause;
    } else {
      $property_accessors .= sprintf q(

## Property: %1$s
## ----------%4$s

sub get_%1$s {
  my $self = shift;
  return $self->{'obj'}{'%2$s'};
}

sub set_%1$s {
  my ( $self, $value ) = @_;%3$s
  $self->{'obj'}{'%2$s'} = $value;
  return $self;
}), $prop_ref->{'code'}, $code, $constraint, q(-) x length $prop_ref->{'code'};
    }
  }
## Now we have to add set/get for has "1" columns

## And for has "many" columns

## For "contains" columns

## Finally we have to add appropriate "Relationship requests"

  $lookup_constants =~ s{\s*^(?=;)}{}mxsg;
  $lookup_constants =~ s{'$}{',}mxsg;
  $lookup_constants = "## no critic (Quotes)$lookup_constants## use critic" if $lookup_constants =~ m{\A\s+'W*'}mxs || $lookup_constants =~ m{'W*',\Z}mxs;

## Generete perl code...
## Now we do the relationship code!
  my $relationship_accessors = q();
  my $has_one_accessors      = q();
  my $has_many_accessors     = q();

  foreach my $has_ref  ( @{$conf->{'has'}||[]} ) {
    if( $has_ref->{'count'} eq 'many' || $has_ref->{'count'} eq 'many-many' ) {
      $has_many_accessors .= sprintf q(
sub get_all_%1$ss {
  my $self = shift;
  return $self->get_other_adaptor( '%2$s' )->fetch_all_%4$ss_by_%3$s( $self );
}
),
        $self->ky( $has_ref->{'alias'} || $has_ref->{'object'} ),
        $has_ref->{'object'},
        $self->ky( $has_ref->{'alias'} || $type ),
        $self->ky( $has_ref->{'object'} ),
        ;
    } else {
      $has_one_accessors .= sprintf q(
sub get_%1$s {
  my $self = shift;
  return $self->get_other_adaptor( '%2$s' )->fetch_%4$s_by_%3$s( $self );
}
),
        $self->ky( $has_ref->{'alias'} || $has_ref->{'object'} ),
        $has_ref->{'object'},
        $self->ky( $has_ref->{'alias'} || $type ),
        $self->ky( $has_ref->{'object'} ),
        ;
    }
  }

  foreach my $rel_name ( $self->relationships ) {
    my $rel_key = $self->ky( $rel_name );
    my $rel_conf = $self->conf( 'relationships', $rel_name );
    my %type_map = map { $_->{'alias'}||$_->{'type'} => $_->{'type'} } @{$rel_conf->{'objects'}};

    foreach my $ky ( sort keys %{$rel_conf->{'fetch_by'}} ) {
      my $ky_mapped = join q(_), map { $self->ky( $_ ) } split m{_}mxs, $ky;
      my @ref = @{$rel_conf->{'fetch_by'}{$ky}};
      my $count = grep { $type_map{$_} eq $type } @ref;
      next unless $count;
      foreach my $iter (1..$count) {
        my $method_name = join q(_), map { $self->ky( $_ ) } grep { $_ ne $type } split m{_}mxs, $ky;
           $method_name = $method_name
                        ? 'get_'.$rel_key.'_by_'.$method_name
                        : 'get_'.$rel_key;
        ## This is a fetch by type...
        my $parameters     = q();
        my $parameter_list = q();
        my $parameter_type_list = q();
        my $indx = 0;
        foreach my $objtype (@ref) {
          if( $type_map{$objtype} eq $type ) {
            $indx++;
            if( $indx == $iter ) {
              $parameter_list .= q(, $self);
              next;
            }
          }
          $parameters     .= q(, $).$self->ky( $objtype );
          $parameter_list .= q(, $).$self->ky( $objtype );
          if( $objtype =~ m{\A[[:upper:]]}mxs ) {
            $parameter_type_list .= "\n".sprintf q(#@param (Pagesmith::Object::%s::%s|int) %s),
              $self->namespace,
              $type_map{$objtype},
              $self->ky($objtype),
              ;
          } else {
            $parameter_type_list .= "\n".sprintf q(#@param (string %s)), $self->ky($objtype);
          }
        }
        $parameter_list =~ s{\A,[ ]}{}mxs;
        $relationship_accessors.= sprintf q(
sub %1$s {
#@param (self)%7$s
#@return (hashref[])
## Return $rel_name results for
  my ($self%2$s) = @_;
  return $self->get_other_adaptor( '%3$s' )->get_%4$s_by_%5$s( %6$s );
}

),
          $method_name,
          $parameters,
          $rel_name,
          $rel_key,
          $ky_mapped,
          $parameter_list,
          $parameter_type_list,
          ;
      }
    }
  }

  my $perl = sprintf q(package Pagesmith::Object::%1$s::%2$s;

## Class for %2$s objects in namespace %1$s.
%3$s
use base qw(Pagesmith::Object::%1$s);

use Const::Fast qw(const);

## Definitions of lookup constants and methods exposing them to forms.
## ===================================================================%6$s

## uid property....
## ----------------

sub uid {
  my $self = shift;
  return $self->{'obj'}{'%4$s'};
}

## Property get/setters
## ====================%5$s

## Has "1" get/setters
## ===================
%7$s
## Has "many" getters
## ==================
%8$s
## Relationship getters!
## =====================
%9$s
## Store method
## =====================

sub store {
  my $self = shift;
  return $self->adaptor->store( $self );
}

## Other fetch functions!
## ======================
## Can add additional fetch functions here! probably hand crafted to get
## the full details...!

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
    $has_one_accessors,              ## %7$
    $has_many_accessors,             ## %8$
    $relationship_accessors,         ## %9$
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}
## use critic

1;

