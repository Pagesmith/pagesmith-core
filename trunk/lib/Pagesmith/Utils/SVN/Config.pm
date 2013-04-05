package Pagesmith::Utils::SVN::Config;

## Support class for SVN submissions
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

use Const::Fast qw(const);


use English qw(-no_match_vars $CHILD_ERROR $PROGRAM_NAME $INPUT_RECORD_SEPARATOR $ERRNO $EVAL_ERROR);

use Carp qw(croak carp);
use YAML::Loader;
use IPC::ShareLite;

use base qw(Pagesmith::Support);

use Pagesmith::Cache;
my $cache;

sub user {
  my $self = shift;
  return $self->{'_user'};
}

sub cache {
  my $self = shift;
  return $cache;
}

sub shared_cache {
  my $self = shift;
  return $self->{'ipc'} ||= IPC::ShareLite->new(
    '-key'     => 1968,
    '-create'  => 'yes',
    '-destroy' => 'no',
  );
}

sub web_cache {
  my $self = shift;
  return $self->{'cache_obj'} ||= Pagesmith::Cache->new( 'config', 'special|access_conf' );
}

sub store_to_shared_cache {
  my $self = shift;
  return if $self->cache_type eq 'NONE';
  return $self->shared_cache->store( $self->json_encode( $cache ) ) if $self->cache_type eq 'IPC';
  return $self->web_cache->set( $cache );
}

sub load_from_shared_cache {
  my $self = shift;
  return if $self->cache_type eq 'NONE';
  if( $self->cache_type eq 'IPC' ) {
    my $encoded_cache = $self->shared_cache->fetch;
    return 0 unless $encoded_cache;
    my $data_structure = $self->json_decode( $encoded_cache );
    $cache = $data_structure;
    return 1;
  }
  my $ch = $self->web_cache;
  $cache = $ch->get;
  return 1;
}


sub cache_type {
  my $self = shift;
  return $self->{'_cache_type'};
}

sub new {
  my( $class, $root_dir, $cache_type, $flush ) = @_;
  $cache_type = 'IPC' unless defined $cache_type;
  $flush      = 0     unless defined $flush;

  my $self = {
    'raw'          => undef,
    'sites'        => {},
    'repositories' => {},
    'users'        => {},
    'groups'       => {},
    'file_types'   => {},
    'file_groups'  => {},
    '_cache_type'  => $cache_type,
    '_root_dir'    => $root_dir,
    '_type'        => undef,
    '_repos'       => undef,
    '_key'         => undef,
    '_user'        => undef,
  };
  bless $self, $class;
  $self->load_from_shared_cache unless $flush;
  $self->load_from_cache;  ## Returns no value if the config isn't parsable!
  return $self;
}

sub get_method_for {
  my( $self, $filename, $prefix ) = @_;
  $prefix = 'check' unless defined $prefix;

  my $subroutine = 'noextension';
  my $extn       = q(-);
  if( $filename =~ m{[.]([-\w]+)\Z}mxs ) {
    $extn = $1;
    unless( $self->{'syntax_map'} ) {
      foreach my $method ( keys %{ $self->{'raw'}{'syntax_checker'} } ) {
        foreach ( @{ $self->{'raw'}{'syntax_checker'}{ $method } } ) {
          $self->{'syntax_map'}{ $_ } = $method;
        }
      }
    }
    $subroutine = exists $self->{'syntax_map'}{ $extn } ? $self->{'syntax_map'}{ $extn } : 'unknown';
  }
  return { ( 'extension' => $extn, 'method' => join q(_), $prefix, $subroutine ) };
}

sub flush_cache {
  my $self = shift;
  $cache = undef;
  return $self;
}

sub _get_structure {
  my( $self, $path, $structure ) = @_;
  my $return_value = 1;
  ## no critic (Filetest_f)
  if( -d $path ) {
    if( opendir my $dh, $path ) {
      while( my $part = readdir $dh ) {
        next if $part =~ m{\A[.]}mxs;
        (my $key = $part) =~ s{[.]yaml\Z}{}mxs;
        $structure->{$key} ||= {};
        $return_value = 0 unless $self->_get_structure( $path.q(/).$part, $structure->{$key} );
      }
    }
  } elsif( -f _ && $path =~ m{[.]yaml}mxs && open my $fh, q(<), $path ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $yaml   = <$fh>.qq(\n);
    close $fh; ## no critic (RequireChecked)
    my $loader = YAML::Loader->new;
    my $struct;
    my $ret_val = eval {
      $struct = $loader->load( $yaml );
    };
    if( $EVAL_ERROR ) {
      carp( sprintf "Syntax error in file: %s\n%s\n\n", $path, $EVAL_ERROR );
      $return_value = 0;
    }  else {
      $structure->{$_} = $struct->{$_} foreach keys %{$struct};
    }
  }
  ## use critic
  return $return_value;
}

sub populate_cache {
  my $self = shift;
  my $structure = {};
  return 0 unless $self->_get_structure( $self->root_dir.'/config/access', $structure );
  return 0 unless $self->parse( $structure );
  $self->store_to_shared_cache();
  return 1;
}

sub load_from_cache {
  my $self = shift;
  unless( $cache ) {
    unless( $self->populate_cache ) {
      carp 'Unable to populate the cache object due to errors in the yaml files';
      return;
    }
  }
  foreach my $key ( keys %{$self} ) {
    $self->{$key} = $cache->{$key} unless $key =~ m{\A_}mxs; ## Do not copy anything starting with a "_"
  }
  return $self;
}

sub parse {
  my( $self, $structure ) = @_;
  $cache->{'raw'} = $structure;
  ## Set up map between repository and site/library
  ## Map users to groups....
  my %grps;
  foreach my $type ( qw(libraries sites) ) {
    foreach my $k ( keys %{ $structure->{$type} } ) {
      $cache->{'repositories'}{ $structure->{$type}{$k}{'repository'} } = [ $type, $k, {} ];
      foreach my $us ( keys %{ $structure->{$type}{$k}{'users'}||{} } ) {
        $cache->{'users'}{$us}++;
      }
      foreach my $gp ( keys %{ $structure->{$type}{$k}{'groups'}||{} } ) {
        $grps{$gp}++;
      }
    }
  }
  foreach my $gp ( keys %grps ) {
    $cache->{'users'}{$_}++ foreach @{ $structure->{'user_groups'}{ $gp } };
  }
  return 1;
}

sub root_dir {
  my $self = shift;
  return $self->{'_root_dir'};
}

sub is_site {
  my $self = shift;
  return $self->type eq 'sites' ? 1 : 0;
}

sub type {
  my $self = shift;
  return $self->{'_type'};
}

sub repos {
  my $self = shift;
  return $self->{'_repos'};
}

sub key {
  my $self = shift;
  return $self->{'_key'};
}

sub set_repos {
  my( $self, $repos ) = @_;
  my ($key) = reverse split m{/}mxs, $repos;
  return 0 unless exists $self->{'repositories'}{ $key };
  $self->{'_repos'} = $key;
  $self->{'_type'}  = $self->{'repositories'}{ $key }[0];
  $self->{'_key' }  = $self->{'repositories'}{ $key }[1];
  return 1;
}

sub is_valid_user {
  my( $self, $user ) = @_;
  return exists $self->{'users'}{ $user };
}

sub set_user {
  my( $self, $user ) = @_;

  $self->{'_user'} = undef;
  $self->{'_groups'} = [];
  if( $self->info( 'users', $user ) ) {
    $self->{'_user'} = $user;
  }

  foreach my $group ( keys %{ $self->info( 'groups' )||{} } ) {
    next unless exists $self->{'raw'}{'user_groups'}{$group};
    foreach my $u ( @{$self->{'raw'}{'user_groups'}{$group}} ) {
      if( $user eq $u ) {
        $self->{'_user'} = $user;
        push @{ $self->{'_groups'} }, $group;
      }
    }
  }
  return $self->{'_user'};
}

sub my_groups {
  my $self = shift;
  return @{ $self->{ '_groups' }||[] };
}

sub can_perform {
  my( $self, $path, $action ) = @_;
  my $branch = q();
  $path .= q(/) unless $path =~ m{/\Z}mxs;
  if( $path =~ m{\A/(trunk|staging|live)(.*)\Z}mxs ) {
    $branch = $1;
    $path   = $2;
  } else {
    return 0;
  }
  return 0 unless $branch eq 'trunk' || $self->{'_user'} eq 'www-core';
  foreach my $gp ( $self->my_groups ) {
    my $gp_conf = $self->info( 'groups', $gp );
    next unless $gp_conf;
    foreach my $pt ( keys %{ $gp_conf } ) {
      my $modified_path = $pt;
      $modified_path .= q(/) unless $modified_path =~ m{/\Z}mxs;
      next if $modified_path ne substr $path,0,length $modified_path;
      my %permissions = map { ($_=>1) } ref $gp_conf->{$pt} ? @{$gp_conf->{$pt}} : ($gp_conf->{$pt});
      return 1 if $permissions{ $action };
    }
  }
  my $us_conf = $self->info( 'users', $self->{'_user'} );
  return 0 unless $us_conf;
  foreach my $pt ( keys %{ $us_conf } ) {
    my $modified_path = $pt;
    $modified_path .= q(/) unless $modified_path =~ m{/\Z}mxs;
    next if $modified_path ne substr $path,0,length $modified_path;
    my %permissions = map { ($_=>1) } ref $us_conf->{$pt} ? @{$us_conf->{$pt}} : ($us_conf->{$pt});
    return 1 if $permissions{ $action };
  }
  return 0;
}

sub info {
  my( $self, @keys ) = @_;
  my $t = $self->{'raw'}{ $self->type }{ $self->key };
  foreach( @keys ) {
    if( ref $t eq 'HASH' ) {
      return unless exists $t->{$_};
      $t = $t->{$_};
    } elsif( ref $t eq 'ARRAY' ) {
      return if $_ >= @{$t};
      return if $_ < -@{$t};
      $t = $t->[$_];
    } else {
      return; ## Trying to get element of a scalar;
    }
  }
  return $t;
}

1;

