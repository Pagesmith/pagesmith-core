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

use Apache2::Const qw(SERVER_ERROR OK NOT_FOUND HTTP_OK);
use APR::URI;
use English qw(-no_match_vars $EVAL_ERROR);
use Const::Fast qw(const);

const my %WRAPPABLE_STATUSES => map { ($_=>1) } qw(0 200 400 401 403 404 405 500 501 502 503);

use Pagesmith::ConfigHash qw(can_cache can_name_space);
use Pagesmith::Apache::Decorate;
use Pagesmith::Action;
use Pagesmith::Cache;
use Pagesmith::Support;

our @EXPORT_OK = qw(my_handler);
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
  return my_handler(
    sub {
      my( $apache_r, $path_info ) = @_;
      shift @{$path_info} if @{$path_info} && $path_info->[0] eq 'action';
      return;
    },
    $r,
  );
}

## no critic (ExcessComplexity)
sub my_handler {
  my( $path_munger, $r ) = @_;
  my $t = Pagesmith::Support->new()->set_r( $r );

  my @t         = split m{(/)}mxs, $r->uri;
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

  ## $extra - contains a data structure returned by the path_munger
  ## which is stored so that it can be retrieved by the action
  ## component later

  my $extra = &{$path_munger}( $r, \@path_info );

  my $module_name = $t->safe_module_name( shift @path_info );
  ## Check namespace ...
  if( $module_name =~ m{\A([[:alpha:]]+)::}mxs && ! can_name_space( $1 ) ) {
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
  my $ch = Pagesmith::Cache->new( 'action',   "$module_name|$cache_key" );
  unless( $t->flush_cache('action') ) {
    my $c = $ch->get;
    if( $c ) {
      $r->content_type( $c->{'content_type'} ) if $c->{'content_type'};
      if( $c->{'content_type'} =~ m{html}mxs ) {
        $r->add_output_filter( \&Pagesmith::Apache::Decorate::handler ); ## no critic (CallsToUnexportedSubs)
        $r->headers_out->set( 'X-Pagesmith-Decor', 'runtime' );
      }
      $r->print( $c->{'content'} );
      $r->set_content_length( length $c->{'content'} );
      $r->headers_out->set( 'X-Pagesmith-CacheFlag', 'Hit' );
      $c->{'response_code'} = OK if $c->{'response_code'} eq HTTP_OK;
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
  if( $r->content_type =~ m{\A(?:text/html|application/xhtml[+]xml)\b}mxs &&
      $r->headers_out->get('X-Pagesmith-Template')||q() ne 'No' &&
      exists $WRAPPABLE_STATUSES{$status}
  ) {
    $r->headers_out->set('X-Pagesmith-Action', "$module_name|$cache_key" );
    $r->headers_out->set('X-Pagesmith-Expiry', $obj_action->cache_expiry );
  } else {
    $ch->set( {
      'content_type'  => $r->content_type,
      'content'       => $obj_action->content,
      'response_code' => $status,
    }, $obj_action->cache_expiry );
  }
  return $status;
}
## use critic

1;
