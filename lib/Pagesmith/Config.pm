package Pagesmith::Config;

## Configuration parsing/caching object...
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

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR $EVAL_ERROR);
use File::Spec;
use File::Basename qw(dirname);
use Hash::Merge qw(merge);
use Readonly qw(Readonly);
use YAML::Loader;

use base qw(Pagesmith::Root);
use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(site_key set_site_key get_config can_cache docroot server_root);

Readonly my $DEFAULT_KEY      => 'dev';
Readonly my $DEFAULT_LOCATION => 'site';
Readonly my $DEFAULT_FILE     => 'config';

sub new {
  my( $class, $params ) = @_;
  my $self = {
    'key'       => exists $params->{'key'}      ? $params->{'key'}      : get_config('ConfigKey'),
    'file'      => exists $params->{'file'}     ? $params->{'file'}     : $DEFAULT_FILE,
    'loc'       => exists $params->{'location'} ? $params->{'location'} : $DEFAULT_LOCATION,
    'override'  => exists $params->{'override'} ? $params->{'override'} : 0,
    'data'      => {},
    'use_cache' => exists $params->{'use_cache'} ? 1 : 0,
  };

  bless $self, $class;
  return $self;
}

sub set_site { ## Required by scripts
  my( $self, $site ) = @_;
  set_site_key( $site ) unless site_key;
  return $self;
}

sub load {
  my( $self, $force ) = @_;
  my $pch;
  $pch = Pagesmith::Cache->new( 'config', qq($self->{'loc'}|$self->{'file'}) ) if $self->{'use_cache'};
  undef $self->{'data'};
  $self->{'data'} = $pch->get if $pch && !$force;
  unless( $self->{'data'} ) {
    my @elements;
    if( $self->{'loc'} eq 'site' ) {
      push @elements, $self->_get_contents( File::Spec->catfile( dirname(docroot), 'data',   'config-local', $self->{'file'}.'.yaml' )) if $self->{'override'};
      push @elements, $self->_get_contents( File::Spec->catfile( dirname(docroot), 'data',   'config', $self->{'file'}.'.yaml' ));
      push @elements, $self->_get_contents( File::Spec->catfile( server_root,                'config-local', $self->{'file'}.'.yaml' )) if $self->{'override'};
      push @elements, $self->_get_contents( File::Spec->catfile( server_root,                'config', $self->{'file'}.'.yaml' ));
    } elsif( $self->{'loc'} eq 'core' ) {
      push @elements, $self->_get_contents( File::Spec->catfile( server_root,                'config-local', $self->{'file'}.'.yaml' )) if $self->{'override'};
      push @elements, $self->_get_contents( File::Spec->catfile( server_root,                'config', $self->{'file'}.'.yaml' ));
    } else {
      push @elements, $self->_get_contents( $self->{'file'}.'.yaml' );
    }
    $self->{'data'} = $self->merge_multi( @elements );

    $self->merge_defaults( $self->{'data'} );
    $pch->set( $self->{'data'} ) if $pch;
  }
  return $self;
}

sub get {
  my( $self, @keys ) = @_;
  my $h = $self->{'data'};
  foreach ( @keys ) {
    if( ref $h eq 'HASH' ) {
      $h = $h->{$_};
    } else {
      last;
    }
  }

  return $h;
}

sub _get_contents {
  my( $self, $filename ) = @_;
  if( open my $fh, '<', $filename ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $contents = <$fh>;

    close $fh; ## no critic (RequireChecked)
    my $yl   = YAML::Loader->new;
    my $hash = eval { $yl->load( $contents ); };
    if( $EVAL_ERROR ) {
      warn "YAML: $filename - $EVAL_ERROR\n";
      return;
    }
    undef $contents;
    my @elements;
    push @elements, $hash->{ $self->{'key'} } if exists $hash->{ $self->{'key'} };
    push @elements, $hash->{'default'}        if exists $hash->{'default'};
    if( @elements > 1 ) {
      return merge( @elements );
    }
    return @elements;
  }
  return;
}

sub merge_multi {
  my ( $self, @array ) = @_;
  return {} unless @array;
  if( ref $array[0] eq 'ARRAY' ) {
    my @res = @{shift @array};
    while( my $ref = shift @array ) {
      @res = @{merge( \@res, $ref )};
    }
    return \@res;
  }
  if( ref $array[0] eq 'HASH' ) {
    my %res = %{shift @array};
    while( my $ref = shift @array ) {
      %res = %{merge( \%res, $ref )};
    }
    return \%res;
  }
  return $array[0];
}

sub merge_defaults {
  my( $self, $ref ) = @_;
  if( ref $ref eq 'HASH' ) {
    foreach ( keys %{$ref} ) {
      next if $_ eq 'default';
      $ref->{$_} = merge( $ref->{$_}, $ref->{'default'} ) if exists $ref->{'default'};
    }
    delete $ref->{'default'};
    foreach ( values %{$ref} ) {
      $self->merge_defaults( $_ ) if ref $_;
    }
  } elsif( ref $ref eq 'ARRAY' ) {
    foreach ( @{$ref} ) {
      $self->merge_defaults( $_ ) if ref $_;
    }
  }
  return $ref;
}

1;
