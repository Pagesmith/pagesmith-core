package Pagesmith::ObjectAccessors;

## Base class for auto-creating methods from configuration...!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Thu, 23 Jan 2014
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');
use feature qw(switch);

my $defaults = {
  'number'  => 0,
  'boolean' => 'no',
};

sub _define {
  my ( $pkg, $fn, $sub ) = @_;
  my $method = $pkg.q(::).$fn;
  no strict 'refs'; ## no critic (NoStrict)
  if( defined &{$method} ) {
    warn qq(Method "$fn" already exists on $pkg - defining "_$fn"\n);
    $method = $pkg.q(::_).$fn;
  }
  *{$method} = $sub;
  use strict;
  return;
}

sub _define_boolean {
  my( $pkg, $k, $default ) = @_;
  _define( $pkg, q(is_).$k, sub {
    my $self = shift;
    return 'yes' eq ($self->{'obj'}{$k}||$default);
  } );
  _define( $pkg, q(off_).$k, sub {
    my $self = shift;
    $self->{'obj'}{$k} = 'no';
    return $self;
  } );
  _define( $pkg, q(on_).$k, sub {
    my $self = shift;
    $self->{'obj'}{$k} = 'yes';
    return $self;
  } );
  _define(  $pkg, q(set_).$k, sub {
    my( $self, $value ) = @_;
    $value = lc $value;
    if( 'yes' eq $value || 'no' eq $value ) {
      $self->{'obj'}{$k} = $value;
    } else {
      warn "Value for $k is incorrect ($value)\n";
    }
    return $self;
  } );
  return;
}

sub _define_enum {
  my( $pkg, $k, $default, $values ) = @_;
  _define( $pkg, q(is_).$k, sub {
    my ( $self, $val ) = @_;
    return $val eq ($self->{'obj'}{$k}||$default)||q();
  } );
  my $values_hash = 'HASH' eq ref $values
                  ? $values
                  : { 'HASH'  eq ref $values->[0] ? map { $_->{'value'} => $_->{'name'} } @{$values}
                    : 'ARRAY' eq ref $values->[0] ? map { $_->[0]       => $_->[1]      } @{$values}
                    :                               map { $_            => $_           } @{$values}
                    };
  my $values_ordered =  'ARRAY' eq ref $values
    ? (
        'HASH'  eq ref $values->[0] ? [ map {$_->{'value'}} @{$values} ]
      : 'ARRAY' eq ref $values->[0] ? [ map {$_->[0]}       @{$values} ]
      :                               $values,
    )
    : [sort { $values->{$a} cmp $values->{$b} } %{$values} ];
  my $ordered_hash = [ map { [ $_ => $values_hash->{$_} ] } @{$values_ordered} ];
  my $ordered_hr   = [ map { $values_hash->{$_} } @{$values_ordered} ];
  _define( $pkg, q(set_).$k, sub {
    my( $self, $value ) = @_;
    if( exists $values_hash->{$value} ) {
      $self->{'obj'}{$k} = $value;
    } else {
      warn "Value for $k is incorrect ($value)\n";
    }
    return $self;
  } );
  my $method_hr  = $pkg, q(get_).$k.q(_hr);
  my $method_all_hr     = $pkg, q(all_).$k.q(_hr);
  my $method_all_sorted = $pkg, q(all_).$k.q(_sorted);
  _define( $pkg, q(get_).$k.q(_hr), sub {
    my $self = shift;
    return $values_hash->{$self->{'obj'}{$k}||$default};
  } );
  _define( $pkg, q(all_).$k.q(_hr), sub {
    return $ordered_hr;
  } );
  _define( $pkg, q(all_).$k.q(_sorted), sub {
    return $ordered_hash;
  } );
  return;
}

sub _define_index {
  my( $pkg, $k ) = @_;
  _define( $pkg, q(set_).$k, sub {
    my ( $self, $value ) = @_;
    if( $value <= 0 ) {
      warn "Trying to set non positive value for '$k'\n";
    } else {
      $self->{'obj'}{$k} = $value;
    }
    return $self;
  } );
  return;
}

sub _define_set {
  my( $pkg, $k ) = @_;
  _define( $pkg, q(set_).$k, sub {
    my($self,$value) = @_;
    $self->{'obj'}{$k} = $value;
    return $self;
  } );
  return;
}
sub make_accessors {
  my( $pkg, $config ) = @_;

  ## Define core object accessors...
  foreach my $k ( keys %{$config->{'obj'}} ) {
    my $defn     = $config->{'obj'}{$k};
       $defn     = { 'type' => $defn } unless ref $defn;
    my $type     = $defn->{'type'};
    my $default  = $defn->{'default'}||( exists $defaults->{$type} ? $defaults->{$type} : undef );

    if( $type eq 'uid' ) {
      _define( $pkg, q(uid), sub {
        my $self = shift;
        return $self->{'obj'}{$k};
      } );
    }

    ## General Get method...
    _define( $pkg, q(get_).$k,sub {
      my $self = shift;
      return defined $self->{'obj'}{$k} ? $self->{'obj'}{$k} : $default;
    } );

    for( $type ) {
      when( $_ eq 'boolean' )           { _define_boolean(  $pkg, $k, $default ); }
      when( $_ eq 'enum'    )           { _define_enum(     $pkg, $k, $default, $defn->{'values'} ); }
      when( $_ eq 'id' || $_ eq 'uid' ) { _define_index(    $pkg, $k ); }
      when( $_ ne 'derived' )           { _define_set(      $pkg, $k ); }
    }
    next unless exists $config->{'rel'}{$k};
    $defn = $config->{'rel'}{$k};
    #### use Data::Dumper; warn "!pre!$pkg--$k--\n".Dumper( $defn );
  }
  return;
}

sub parse_rel {
  my ( $defn, $type ) = @_;
  my $rel = {};
  foreach my $k (keys %{$defn->{'relationships'}}) {
    next unless exists $defn->{'relationships'}{$k}{$type}{'to'};
    my $t = $defn->{'relationships'}{$k}{$type};
    return { 'to' => [ $k, @{$t->{'to'}} ], 'additional' => exists $t->{'additional'} ? $t->{'additional'} : {} };
  }
  return {};
}

sub parse_defn {
  my ( $defn, $type ) = @_;
  my $definition = { 'obj' => $defn->{'objects'}{$type}, 'rel' => {} };
  if( exists $defn->{'objects'}{$type} ) {
    foreach my $k (keys %{$defn->{'relationships'}{$type}} ) {
      my $c = $defn->{'relationships'}{$type}{$k};
      if( exists $c->{'from'} && !exists $c->{'via'}) {
        my $t = $defn->{'relationships'}{$c->{'from'}};
        $c = { 'to'         => [ $c->{'from'}, grep { $_ ne $type } @{$t->{$k}{'to'}} ],
               'additional' => exists $t->{$k}{'additional'} ? $t->{$k}{'additional'} : {} };
      }
      $definition->{'rel'}{$k}=$c;
    }
  }
  return $definition;
}

sub init {
  my( $self, $hashref, $partial ) = @_;
  $self->{'obj'} = {%{$hashref}};
  $self->flag_as_partial if defined $partial && $partial;
  return;
}

sub type {
#@param ($self)
#@return (String);
## Gets the type of object (basically anything after the last ::)
  my $self = shift;
  my ( $type ) = (ref $self) =~ m{([^:]+)\Z}mxsg;
  return $type;
}

1;
