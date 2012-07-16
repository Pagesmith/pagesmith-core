package Pagesmith::Apache::Params;

## Setting up configurations from Apache configuration!
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings 'FATAL' => 'all';
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Apache2::CmdParms  ();
use Apache2::Const qw(OR_ALL ITERATE TAKE1 RSRC_CONF);
use Apache2::Directive ();
use Apache2::Module    ();

## Possibly multivalued parameters
my @directives = map { {
    'name'         => "Pagesmith_$_",
    'args_how'     => ITERATE,
    'func'         => __PACKAGE__ . '::set_'.lc($_),
    'errmsg'       => "$_ (Entry)+",
    'req_override' => OR_ALL,
  }
  } qw(
  MC_Server MC_Option
  SQL_Option
  FILE_Option
  Proxy_NoProxy
);

## Single valued parameters
push @directives, map { {
    'name'         => "Pagesmith_$_",
    'args_how'     => TAKE1,
    'func'         => __PACKAGE__ . '::set_'.lc($_),
    'errmsg'       => "$_ Entry",
    'req_override' => OR_ALL,
  }
  } qw(
  SQL_DSN SQL_User SQL_Pass
  FILE_Path
  Proxy_URL
  Config_Prefix
);

Apache2::Module::add( __PACKAGE__, \@directives );  ##no critic (CallsToUnexportedSubs)

sub set_mc_server {
  my @pars = @_;
  push_val( 'MC_Server', @pars );
  return;
}

sub set_mc_option {
  my @pars = @_;
  push_val( 'MC_Option', @pars );
  return;
}

sub set_sql_option {
  my @pars = @_;
  push_val( 'SQL_Option', @pars );
  return;
}

sub set_sql_dsn  {
  my @pars = @_;
  set_val( 'SQL_Dsn',  @pars );
  return;
}

sub set_sql_user {
  my @pars = @_;
  set_val( 'SQL_User', @pars );
  return;
}

sub set_sql_pass {
  my @pars = @_;
  set_val( 'SQL_Pass', @pars );
  return;
}

sub set_file_option {
  my @pars = @_;
  push_val( 'FILE_Option', @pars );
  return;
}

sub set_file_path {
  my @pars = @_;
  set_val( 'FILE_Path', @pars );
  return;
}

sub set_proxy_noproxy {
  my @pars = @_;
  push_val( 'Proxy_NoProxy', @pars );
  return;
}

sub set_proxy_url {
  my @pars = @_;
  set_val( 'Proxy_URL', @pars );
  return;
}

sub set_config_prefix {
  my @pars = @_;
  set_val( 'Config_Prefix', @pars );
  return;
}

sub set_val {
  my ( $key, $self, $parms, $arg ) = @_;
  $self->{$key} = $arg;
  unless ( $parms->path ) {
    my $srv_cfg = Apache2::Module::get_config( $self, $parms->server );  ##no critic (CallsToUnexportedSubs)
    $srv_cfg->{$key} = $arg;
  }
  return;
}

sub push_val {
  my ( $key, $self, $parms, $arg ) = @_;
  push @{ $self->{$key} }, $arg;
  unless ( $parms->path ) {
    my $srv_cfg = Apache2::Module::get_config( $self, $parms->server ); ##no critic (CallsToUnexportedSubs)
    push @{ $srv_cfg->{$key} }, $arg;
  }
  return;
}

sub mc_servers {
  my $self = shift;
  return @{ $self->{'MC_Server'} || [] };
}

sub mc_options {
  my $self = shift;
  return @{ $self->{'MC_Option'} || [] };
}

sub sql_options {
  my $self = shift;
  return @{ $self->{'SQL_Option'} || [] };
}

sub sql_dsn  {
  my $self = shift;
  return $self->{'SQL_Dsn'}  || undef;
}

sub sql_user {
  my $self = shift;
  return $self->{'SQL_User'} || undef;
}

sub sql_pass {
  my $self = shift;
  return $self->{'SQL_Pass'} || undef;
}

sub fs_options {
  my $self = shift;
  return @{ $self->{'FILE_Option'} || [] };
}

sub fs_path {
  my $self = shift;
  return $self->{'FILE_Path'} || undef;
}

sub config_prefix {
  my $self = shift;
  return $self->{'Config_Prefix'} || undef;
}

sub proxy_noproxy {
  my $self = shift;
  return @{ $self->{'Proxy_NoProxy'} || [] };
}

sub proxy_url {
  my $self = shift;
  return $self->{'Proxy_URL'} || undef;
}

1;
