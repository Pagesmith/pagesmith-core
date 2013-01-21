package Pagesmith::ConfigHash;

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

use base qw(Exporter);

use Apache2::RequestRec;
use Apache2::RequestUtil;
use File::Basename qw(dirname);
use File::Spec;

our @EXPORT_OK = qw(
  set_site_key  site_key          set_r       r override_config
  set_proxy_url set_proxy_noproxy devel_realm is_developer  data  get_config set_config
  server_root   init_data         can_cache   docroot       port  server
  template_name template_dir      proxy_url   proxy_noproxy hash  set_key_root
  site_root     can_name_space
);

our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

my $config_data = {};
my $site_key;
my $r;
my $key_root;

my $defaults = { qw(
    RealTmp         /tmp/
    JsFlag          none
    CssFlag         none
    DocType         strict
    ContentType     xhtml_html
    CacheType       MS
    TmpUrl          /t/
    TmpDir          /www/tmp/www-trunk/tmp/
    ConfigKey       dev
    ServerStatus    unknown
    AuthServer      http://localhost
    AuthKey         default
    AuthToken       d3f4ultTok3N
    AuthSecret      Def4ult53C73?
    AuthExpireUnit  day
    AuthExpireCount 1
    AuthTimeout     3
    CookieToken     C0@kiE?0Ken
    QrURL           /qr/
    QrEnabled       0
    LdapURL         localhost
    Editable        none
    Staging         false
    CachePageParams false
  ),
  map { ($_,undef) } qw( ProxyURL Domain RequiredDiv AltCacheSite ),
};

sub init_data {
  $config_data = {};
  return;
}

sub set_key_root {
  my $val = shift;
  $key_root = $val;
  return;
}
sub set_site_key {
  my $val = shift;
  $site_key = $val;
  return;
}

sub site_key {
  return $site_key;
}

sub set_r {
  my $val = shift;
  $r = $val;
  return;
}

sub r {
  return $r;
}

sub data {
  return $config_data;
}

sub set_config {
  my( $key, $value ) = @_;
  unless ( exists $config_data->{$site_key}{$key} ) {
    $config_data->{$site_key}{$key} = $value;
  }
  return $config_data->{$site_key}{$key};
}

sub override_config {
  my( $key, $value ) = @_;
  return $config_data->{$site_key}{$key} = $value;
}

sub get_config {
  my $key = shift;
  unless ( exists $config_data->{$site_key}{$key} ) {
    if( $r ) {
      $config_data->{$site_key}{$key} = $r->dir_config( $key_root . '_' . $key ) || $defaults->{$key};
    } else {
      $config_data->{$site_key}{$key} = $defaults->{$key};
    }
  }
  return $config_data->{$site_key}{$key};
}

sub hash {
  my %hash = ( %{$defaults}, %{ $config_data->{$site_key} } );
  return \%hash;
}

sub can_cache {
  my $key = shift;
  unless ( exists $config_data->{$site_key}{'-cache_flags'} ) {
    if($r) {
      my @T = $r->dir_config->get( $key_root . '_Cache_Flags' );
      $config_data->{$site_key}{'-cache_flags'} = { map { ( $_ => 1 ) } @T };
    }
  }
  return $config_data->{$site_key}{'-cache_flags'}{$key};
}

sub can_name_space {
  my $key = shift;
  unless ( exists $config_data->{$site_key}{'-name_spaces'} ) {
    if($r) {
      my @T = $r->dir_config->get( $key_root . '_NameSpace' );
      $config_data->{$site_key}{'-name_spaces'} = { map { ( $_ => 1 ) } @T, 'Developer' => 1 }; ## Developer is now in all sites name spaces, but blocked elsewhere
    }
  }
  return $config_data->{$site_key}{'-name_spaces'}{$key};
}

sub is_developer {
  my $realms = shift;
  return 0 unless $realms;
  unless ( exists $config_data->{$site_key}{'-is_developer'}{ $realms } ) {
    $config_data->{$site_key}{'-is_developer'}{ $realms } = ( get_config('ServerStatus') eq 'devel' ) && ( grep { devel_realm($_) } split m{\W+}mxs, $realms );
  }
  return $config_data->{$site_key}{'-is_developer'}{ $realms };
}

sub devel_realm {
  my $key = shift;
  unless ( exists $config_data->{$site_key}{'-devel_realms'} ) {
    my @T = $r->dir_config->get( $key_root . '_DevelRealm' );
    $config_data->{$site_key}{'-devel_realms'} = { map { ( $_ => 1 ) } @T };
  }
  return $config_data->{$site_key}{'-devel_realms'}{$key};
}

sub template_name {
  return $config_data->{$site_key}{'-template_name'} ||= get_config( 'Domain' ) || $r->server->server_hostname;
}
sub server_root {
  return $config_data->{'-server_root'} ||= dirname(dirname(dirname(File::Spec->rel2abs(__FILE__))));
}

sub site_root {
  return $config_data->{$site_key}{'-site_root'} ||= dirname( docroot() );
}

sub docroot {
  return $config_data->{$site_key}{'-docroot'} ||= $r ? $r->document_root : File::Spec->catfile( server_root, 'sites', $site_key, 'htdocs' );
}

sub server {
  return $config_data->{$site_key}{'-server'} ||= $r->hostname;
}

sub port {
  return $config_data->{$site_key}{'-port'} ||= $r->get_server_port;
}

sub template_dir {
  unless ( exists $config_data->{$site_key}{'-template_path'} ) {
    $config_data->{$site_key}{'-template_path'} = File::Spec->catfile( site_root(), 'data', 'templates' );
  }
  return $config_data->{$site_key}{'-template_path'};
}

## Now for the global settings...!
sub set_proxy_url {
  my $val = shift;
  return $config_data->{'-proxy_url'} = $val;
}

sub proxy_url {
  return $config_data->{'-proxy_url'};
}

sub set_proxy_noproxy {
  my $val = shift;
  return $config_data->{'-proxy_noproxy'} = $val;
}

sub proxy_noproxy {
  return $config_data->{'-proxy_noproxy'};
}

1;

