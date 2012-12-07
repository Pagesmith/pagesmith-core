package Pagesmith::Apache::Action;

## Apache handler for action classes
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

use base qw(Exporter);

use Apache2::Const qw(SERVER_ERROR OK NOT_FOUND);
use APR::URI;
use English qw(-no_match_vars $EVAL_ERROR);

use Pagesmith::ConfigHash qw(can_cache can_name_space);
use Pagesmith::Action;
use Pagesmith::Cache;
use Pagesmith::Support;

our @EXPORT_OK = qw(_handler);
our %EXPORT_TAGS = ('ALL' => \@EXPORT_OK);

sub munge_path {
  my( $r, $rpath, $path_info ) = @_;
  if ( $rpath =~ m{\A/(\w+)}mxs ) {
    unshift @{$path_info}, $1 unless $1 eq 'action';
  }
  return;
}

sub handler {
  my $r = shift;
  return _handler(
    sub {
      my( $apache_r, $rpath, $path_info ) = @_;
      if ( $rpath =~ m{\A/(\w+)}mxs ) {
        unshift @{$path_info}, $1 unless $1 eq 'action';
      }
      return;
    },
    $r,
  );
}

sub _handler {
  my( $path_munger, $r ) = @_;
  my $t = Pagesmith::Support->new()->set_r( $r );

  my @t         = split m{(/)}mxs, $r->path_info;
  my @path_info;
  my $y;
  while (@t) {
    my $x = shift @t;
    push @path_info, $x;
    $y = shift @t;
  }

  push @path_info, q() if defined $y;
  shift @path_info;

  my $parsed = APR::URI->parse($r->pool, $r->uri);

  my $extra = &{$path_munger}( $r, $parsed->rpath, \@path_info );

  my $module_name = $t->safe_module_name( shift @path_info );
  ## Check namespace ...
  if( $module_name =~ m{\A([a-z]+)::}mxis && ! can_name_space( $1 ) ) {
    warn "ACTION: cannot perform $module_name - not in valid name space\n";
    return NOT_FOUND;
  }
  my $class       = 'Pagesmith::Action::' . $module_name;
  $r->filename( $class );
  unless ( $t->dynamic_use($class) ) {
    (my $fn = $module_name ) =~ s{::}{/}mxgs;
    if( $t->dynamic_use_failure($class) =~ m{\ACan't\slocate\sPagesmith/Action/$fn.pm}mxs ) {
      warn "ACTION: $class failed to compile: ".$t->dynamic_use_failure($class)."\n";
      return NOT_FOUND;
    }
    warn "ACTION: $class failed to compile: ".$t->dynamic_use_failure($class)."\n";
    return SERVER_ERROR;
  }
  my $obj_action;
  my $status = eval { $obj_action = $class->new( { 'path_info' => \@path_info, 'r' => $r, 'extra' => $extra } ); };
  if( $EVAL_ERROR ) {
    warn "ACTION: $class failed to instantiate: $EVAL_ERROR\n";
    return SERVER_ERROR;
  }
  my $cache_key  = can_cache('actions') ? $obj_action->cache_key : undef;
  ## We are not going to cache this so just return it!
  unless ($cache_key) {
    my $eval_status = eval { $obj_action->run(); };
    return $eval_status unless $EVAL_ERROR;
    warn "ACTION: $class failed to execute: $EVAL_ERROR\n";
    return SERVER_ERROR;
  }
  $obj_action->enable_caching;
  ## Look up value in cache
  $module_name =~ s{::}{__}mxgs;
  my $ch = Pagesmith::Cache->new( 'action', "$module_name|$cache_key" );
  $r->headers_out->set( 'X-Pagesmith-Cache', "$module_name|$cache_key" );
  unless( $t->flush_cache('action') ) {
    my $c = $ch->get;
    if( $c ) {
      $r->content_type( $c->{'content_type'} ) if $c->{'content_type'};
      $r->print( $c->{'content'} );
      $r->headers_out->set( 'X-Pagesmith-CacheFlag', 'Hit' );
      return $c->{'response_code'};
    }
    $r->headers_out->set( 'X-Pagesmith-CacheFlag', 'Miss' );
  } else {
    $r->headers_out->set( 'X-Pagesmith-CacheFlag', 'Flush' );
  }
  $status = eval { $obj_action->run(); };
  if( $EVAL_ERROR ) {
    warn "ACTION: $class failed to execute: $EVAL_ERROR\n";
    return SERVER_ERROR;
  }
  $ch->set( {
    'content_type'  => $r->content_type,
    'content'       => $obj_action->content,
    'response_code' => $status,
  }, $obj_action->cache_expiry );
  return $status;
}

1;
