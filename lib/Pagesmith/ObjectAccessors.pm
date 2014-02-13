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
use Const::Fast qw(const);


const my $DEFAULTS => {
  'number'  => 0,
  'boolean' => 'no',
};

## This will need our standard get other adaptor method call!

## Functions to define accessors for objects....

sub create_method {
  my ( $pkg, $fn, $sub ) = @_;
  my $method = $pkg.q(::).$fn;
  no strict 'refs'; ## no critic (NoStrict)
  if( defined &{$method} ) {
    warn qq(Method "$fn" already exists on $pkg - defining "std_$fn"\n);
    $fn = "std_$fn";
    $method = $pkg.q(::).$fn;
  }
  if( 'CODE' eq ref $sub ) {
    *{$method} = $sub;
  } else {
    *{$method} = eval $sub; ## no critic (StringyEval)
  }
  use strict;
  return $fn;
}

sub define_boolean {
  my( $pkg, $k, $default ) = @_;
  return (
    create_method( $pkg, q(is_).$k, sub {
      my $self = shift;
      return 'yes' eq ($self->{'obj'}{$k}||$default);
    } ),
    create_method( $pkg, q(off_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 'no';
      return $self;
    } ),
    create_method( $pkg, q(on_).$k, sub {
      my $self = shift;
      $self->{'obj'}{$k} = 'yes';
      return $self;
    } ),
    create_method(  $pkg, q(set_).$k, sub {
      my( $self, $value ) = @_;
      $value = lc $value;
      if( 'yes' eq $value || 'no' eq $value ) {
        $self->{'obj'}{$k} = $value;
      } else {
        warn "Value for $k is incorrect ($value)\n";
      }
      return $self;
    } ),
  );
}

sub define_enum {
  my( $pkg, $k, $default, $values ) = @_;
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
  my $method_hr  = $pkg, q(get_).$k.q(_hr);
  my $method_all_hr     = $pkg, q(all_).$k.q(_hr);
  my $method_all_sorted = $pkg, q(all_).$k.q(_sorted);

  return (
    create_method( $pkg, q(is_).$k, sub {
      my ( $self, $val ) = @_;
      return $val eq ($self->{'obj'}{$k}||$default)||q();
    } ),
    create_method( $pkg, q(set_).$k, sub {
      my( $self, $value ) = @_;
      if( exists $values_hash->{$value} ) {
        $self->{'obj'}{$k} = $value;
      } else {
        warn "Value for $k is incorrect ($value)\n";
      }
      return $self;
    } ),
    create_method( $pkg, q(get_).$k.q(_hr), sub {
      my $self = shift;
      return $values_hash->{$self->{'obj'}{$k}||$default};
    } ),
    create_method( $pkg, q(all_).$k.q(_hr), sub {
      return $ordered_hr;
    } ),
    create_method( $pkg, q(all_).$k.q(_sorted), sub {
      return $ordered_hash;
    } ),
    create_method( $pkg, $k.q(_hr), sub {
      return map { exists $values_hash->{$_} ? $values_hash->{$_} : () } @_;
    } ),
  );
}

sub define_index {
  my( $pkg, $k ) = @_;
  return create_method( $pkg, q(set_).$k, sub {
    my ( $self, $value ) = @_;
    if( $value <= 0 ) {
      warn "Trying to set non positive value for '$k'\n";
    } else {
      $self->{'obj'}{$k} = $value;
    }
    return $self;
  } );
}

sub define_set {
  my( $pkg, $k ) = @_;
  return create_method( $pkg, q(set_).$k, sub {
    my($self,$value) = @_;
    $self->{'obj'}{$k} = $value;
    return $self;
  } );
}

sub define_get {
  my( $pkg, $k, $default ) = @_;
  return create_method( $pkg, q(get_).$k, sub {
    my $self = shift;
    return defined $self->{'obj'}{$k} ? $self->{'obj'}{$k} : $default;
  } );
}

sub define_uid {
  my( $pkg, $k ) = @_;
  return create_method( $pkg, q(uid), sub {
    my $self = shift;
    return $self->{'obj'}{$k};
  } );
}

sub define_related_get_set {
  my( $pkg, $type, $k, $derived ) = @_;
  my $fetch_method = 'fetch_'.lc $type;
  my $get_method   = 'get_'.$k;
  (my $obj_key = $k) =~ s{_id\Z}{}mxsg;
  ## Object/get setters!
  ## no critic (InterpolationOfMetachars)
  return (
    create_method( $pkg, 'get_'.$obj_key, sub {
      my $self = shift;
      return $self->get_other_adaptor( $type )->$fetch_method( $self->$get_method );
    } ),
    create_method(
      $pkg, 'set_'.$obj_key, sprintf q(sub {
      my ( $self, $%1$s ) = @_;
      $%1$s = $self->get_other_adaptor( '%2$s' )->%3$s( $%1$s ) unless ref $%1$s;
      if( $%1$s ) {
        $self->{'obj'}{'%4$s'} = $%1$s->uid;%5$s
      }
      return $self;
    }),
      $obj_key, $type, $fetch_method, $k,
      join q(),
      map { sprintf "\n".q(    $self->{'obj'}{'%s'} = $%s->get_%s;), $derived->{$_}, $obj_key, $_ }
      keys %{$derived},
    ),
  );
  ## use critic
}

sub define_related_get_all {
  my( $pkg, $type, $k, $my_type ) = @_;
  my $method = sprintf 'fetch_%s_by_%s', $k, lc $my_type;
  return create_method( $pkg, q(get_all_).$k, sub {
    my $self = shift;
    return $self->get_other_adaptor( $type )->$method( $self );
  } );
}

sub define_related_get_rel {
  my( $pkg, $k, $my_type ) = @_;
  my $method = sprintf 'get_%s_by_%s', lc $k, lc $my_type;
  return create_method( $pkg, 'get_'.lc $k, sub {
    my $self = shift;
    return $self->get_other_adaptor( $k )->$method( $self );
  } );
}

sub make_accessors {
  my( $pkg, $config ) = @_;
  my @methods;
  ## Main object properties
  foreach my $k ( keys %{$config->{'properties'}} ) {
    my $defn     = $config->{'properties'}{$k};
       $defn     = { 'type' => $defn } unless ref $defn;
    my $type     = $defn->{'type'};
    my $default  = exists $defn->{'default'} ? $defn->{'default'}
                 : exists $DEFAULTS->{$type} ? $DEFAULTS->{$type}
                 :                             undef
                 ;

    push @methods, define_get( $pkg, $k, $default );          ## General Get method...
    push @methods, define_uid( $pkg, $k )  if $type eq 'uid'; ## unique ID property!;

    for( $type ) {                             ## Methods for different object types...
      when( $_ eq 'boolean' )           { push @methods, define_boolean(  $pkg, $k, $default ); }
      when( $_ eq 'enum'    )           { push @methods, define_enum(     $pkg, $k, $default, $defn->{'values'} ); }
      when( $_ eq 'id' || $_ eq 'uid' ) { push @methods, define_index(    $pkg, $k ); }
      default                           { push @methods, define_set(      $pkg, $k ); }
    }
  }

  ## Now we need to look at the relationships between objects...
  foreach my $k ( keys %{$config->{'related'}} ) {
    my $defn = $config->{'related'}{$k};
    if( exists $defn->{'to'} ) {        ## object has a single related object!
      push @methods, define_get(   $pkg, $k );
      push @methods, define_index( $pkg, $k );
      my %derived;
      ## derived get_calls!
      if( exists $defn->{'derived'} ) {
        %derived = %{$defn->{'derived'}};
        push @methods, define_get( $pkg, $_ ) foreach values %derived;
      }
      push @methods, define_related_get_set( $pkg, $defn->{'to'}, $k, \%derived );
    } elsif( exists $defn->{'from'} ) { ## object has multiple related objects...
      ## This is a many-1 relationship
      push @methods, define_related_get_all( $pkg, $defn->{'from'}, $k, $config->{'type'} );
    } else {                            ## This is a "relationship" with added attributes!
      push @methods, define_related_get_rel( $pkg, $k, $config->{'type'} );
    }
  }
  create_method( $pkg, 'auto_methods', sub { my @m = sort 'auto_methods', @methods; return @m; });
  return;
}

## Functions that munge the object configuration structure
## Merge in relationships!

sub parse_defn {
  my ( $defn, $type ) = @_;
  my $d = $defn->{'objects'}{$type};
  my $definition = {
    'type'           => $type,
    'properties'     => $d->{'properties'},
    'related'        => {},
  };

  foreach (qw(properties plural audit)) {
    $definition->{$_} = $d->{$_} if exists $d->{$_};
  }
  $definition->{'plural'} = $d->{'plural'} if exists $d->{'plural'};
  if( exists $d->{'related'} ) {
    $definition->{'related'}{$_} = $d->{'related'}{$_} foreach keys %{$d->{'related'}};
  }

  if( exists $defn->{'relationships'} ) {
    $definition->{'related'}{$_} = $defn->{'relationships'}{$_} foreach
      grep { exists $defn->{'relationships'}{$_}{'objects'}{$type} }
      keys %{$defn->{'relationships'}};
  }

  return $definition;
}

## This is the really nasty function which squirts methods into the
## Support namespace to define the methods in the Object/Adaptor
## classes...

sub bake_model {
##@param (string) package name
##@param (hashref) defn of objects of relationships
##
## Pushes four methods:
##
## * my_defn       - returns defn for object used in Object/Adaptor code
## * my_rels       - returns defn for relationship used in Adaptor code?
## * my_obj_types  - returns list of Object types
## * my_rel_types  - returns list of Relationship types

  my( $pkg, $DEFN ) = @_;
  my @methods = (
    create_method( $pkg, 'my_obj_types', sub {
      return unless exists $DEFN->{'objects'};
      my @m = sort keys %{$DEFN->{'objects'}};
      return @m;
    } ),
    create_method( $pkg, 'my_rel_types', sub {
      return unless exists $DEFN->{'relationships'};
      my @m = sort keys %{$DEFN->{'relationships'}};
      return @m;
    } ),
    create_method( $pkg, 'my_defn', sub {
      my $type = shift;
      return parse_defn( $DEFN, $type );
    } ),
  );
  create_method( $pkg, 'auto_methods', sub { my @m = sort 'auto_methods', @methods; return @m; });
  return;
}

## Now we have the standard methods for this sub-class of objects which we want to define
## These are added to the base class!!
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

sub get_created_at {
  my $self = shift;
  return $self->{'obj'}{'created_at'};
}

sub set_created_at {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_at'} = $value;
  return $self;
}

sub get_created_by_id {
  my $self = shift;
  return $self->{'obj'}{'created_by_id'}||0;
}

sub set_created_by_id {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_by_id'} = $value;
  return $self;
}

sub get_created_by {
  my $self = shift;
  return $self->{'obj'}{'created_by'}||0;
}

sub set_created_by {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_by'} = $value;
  return $self;
}

sub get_created_ip {
  my $self = shift;
  return $self->{'obj'}{'created_ip'};
}

sub set_created_ip {
  my( $self, $value ) = @_;
  $self->{'obj'}{'ip'} = $value;
  return $self;
}

sub get_created_useragent {
  my $self = shift;
  return $self->{'obj'}{'created_useragent'};
}

sub set_created_useragent {
  my( $self, $value ) = @_;
  $self->{'obj'}{'created_useragent'} = $value;
  return $self;
}

sub get_updated_at {
  my $self = shift;
  return $self->{'obj'}{'updated_at'};
}

sub set_updated_at {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_at'} = $value;
  return $self;
}

sub get_updated_by {
  my $self = shift;
  return $self->{'obj'}{'updated_by'}||0;
}

sub set_updated_by {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_by'} = $value;
  return $self;
}

sub get_updated_by_id {
  my $self = shift;
  return $self->{'obj'}{'updated_by_id'}||0;
}

sub set_updated_by_id {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_by_id'} = $value;
  return $self;
}

sub get_updated_ip {
  my $self = shift;
  return $self->{'obj'}{'updated_ip'};
}

sub set_updated_ip {
  my( $self, $value ) = @_;
  $self->{'obj'}{'ip'} = $value;
  return $self;
}

sub get_updated_useragent {
  my $self = shift;
  return $self->{'obj'}{'updated_useragent'};
}

sub set_updated_useragent {
  my( $self, $value ) = @_;
  $self->{'obj'}{'updated_useragent'} = $value;
  return $self;
}

sub store {
  my $self = shift;
  return $self->adaptor->store( $self );
}

sub remove {
  my $self = shift;
  return unless $self->adaptor->can( 'remove' );
  return $self->adaptor->remove( $self );
}

sub get_other_adaptor {
  my( $self, $type ) = @_;
  return $self->adaptor->get_other_adaptor( $type );
}

sub set_attribute {
  my ( $self, $name, $value ) = @_;
  $self->{'attributes'}||={};
  $self->{'attributes'}{$name} = $value;
  return $self;
}

sub get_attribute {
  my ( $self, $name, $default ) = @_;
  return exists $self->{'attributes'}{$name} ? $self->{'attributes'}{$name} : $default;
}

sub get_attribute_names {
  my $self = shift;
  $self->{'attributes'}||={};
  return keys %{$self->{'attributes'}};
}

sub unset_attribute {
  my( $self, $name ) = @_;
  $self->{'attributes'}||={};
  return unless exists $self->{'attributes'}{$name};
  return delete $self->{'attributes'}{$name};
}

sub reset_attributes {
  my $self = shift;
  $self->{'attributes'} = {};
  return $self;
}

1;
