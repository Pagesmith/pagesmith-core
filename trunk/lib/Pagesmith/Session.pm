package Pagesmith::Session;

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

use Readonly qw(Readonly);

Readonly my $MINUTE      => 60;
Readonly my $HOUR        => 60 * $MINUTE;
Readonly my $DAY         => 24 * $HOUR;
Readonly my $WEEK        =>  7 * $DAY;
Readonly my $FRACTION    =>  7;

Readonly my $END_OF_TIME => (1<<31)-1;

use Carp qw(carp);
use Crypt::CBC;
use English qw(-no_match_vars $EVAL_ERROR);

use base qw(Pagesmith::Support);

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Core qw(safe_base64_decode safe_base64_encode);
use Apache2::Cookie;

sub new {
  my( $class, $r, $params ) = @_;
  $params ||= {};

  my $type    = $params->{'type'}    || 'Session';

  ( my $unit  = get_config( 'AuthExpireUnit' ) ) =~ s{s\Z}{}mxs; ## Remove trailing "s"....
  my $unit_value = $unit eq 'week'   ? $WEEK
                 : $unit eq 'day'    ? $DAY
                 : $unit eq 'hour'   ? $HOUR
                 : $unit eq 'minute' ? $MINUTE
                 :                     1 # Defalt to seconds!
                 ;

  my $self = {
    'type'            => $type,
    'uuid'            => undef,
    'cache'           => undef,
    'cookie_name'     => "Pagesmith_$type",
    'cookie_token'    => get_config( 'CookieToken' ),
    '_r'              => $r,
    'expiry_time'     => undef,
    'refresh_time'    => undef,
    'data'            => {},
    'permanent'       => 0,
    'inactive_expiry' => $unit_value * get_config( 'AuthExpireCount' ),
    'ssl_only'        => $params->{'ssl_only'} || 0,
    'ip'              => ':::::',
  };

  bless $self, $class;
  return $self;
}

sub ip {
  my $self = shift;
  return $self->{'ip'};
}

sub r {
  my $self = shift;
  return $self->{'_r'};
}

sub inactive_expiry {
  my $self = shift;
  return $self->{'inactive_expiry'};
}

sub encrypt_key {
  my $self = shift;
  return $self->{'encrypt_key'};
}

sub type {
  my $self = shift;
  return $self->{'type'};
}

sub cookie_name {
  my $self = shift;
  return $self->{'cookie_name'};
}

sub data {
  my $self = shift;
  return $self->{'data'};
}

sub uuid {
  my $self = shift;
  return $self->{'uuid'};
}

sub api_key {
  my $self = shift;
  return $self->{'api_key'};
}

sub expiry_time {
  my $self = shift;
  return $self->{'expiry_time'};
}

sub ssl_only {
  my $self = shift;
  return $self->{'ssl_only'};
}

sub refresh_time {
  my $self = shift;
  return $self->{'refresh_time'};
}

sub permanent {
  my $self = shift;
  return $self->{'permanent'};
}

sub cache {
  my $self = shift;
  return unless $self->{'uuid'};
  return $self->{'cache'} ||= Pagesmith::Cache->new( 'session', "$self->{'type'}|$self->{'uuid'}" );
}

sub store {
  my $self = shift;
  $self->cache->set( $self->encrypt( $self->data, 1 ), $self->expiry_time );
  return $self;
}

sub write_cookie {
  my $self = shift;
  my %params = (
    '-path'  => q(/),
    '-name'  => $self->cookie_name,
    '-value' => $self->generate_cookie_value,
  );
  $params{ 'expires' } = $END_OF_TIME - time if $self->permanent;

  my $cookie_string = Apache2::Cookie->new(
    $self->{'_r'},
    %params,
  ).'; HttpOnly';
  $cookie_string .= '; Secure' if $self->ssl_only;

  $self->r->err_headers_out->add( 'Set-Cookie' => $cookie_string );
  return $self;
}

sub clear {
  my $self = shift;
  $self->cache->unset;
  return $self;
}

sub clear_cookie {
  my $self = shift;
  my %params = (
    '-path'  => q(/),
    '-name'  => $self->cookie_name,
    '-value' => q(),
    '-expires' => 0,
  );
  my $cookie_string = Apache2::Cookie->new(
    $self->{'_r'},
    %params,
  ).'; HttpOnly';

  $cookie_string .= '; Secure' if $self->ssl_only;

  $self->r->err_headers_out->add( 'Set-Cookie' => $cookie_string );
  return $self;
}

sub touch {
  my $self = shift;
  $self->{'refresh_time'} = time + $self->{'inactive_expiry'}/$FRACTION;
  $self->{'expiry_time'}  = $self->{'refresh_time'} + $self->{'inactive_expiry'};
  return $self;
}

sub _initialize {
  my( $self, $params ) = @_;
  $self->{'data'} = $params;
  return $self;
}

sub fetch {
  my( $self, $force ) = @_;
  return unless $self->cache;
  if( $force || ! keys %{$self->{'data'}} ) {
    my $val = $self->cache->get;
    $self->{'data'} = $self->decrypt( $val, 1 );
  }
  return $self->{'data'};
}

sub initialize {
  my( $self, $params, $permanent ) = @_;
  $self->{'permanent'} = $permanent||0;
  $self->{'uuid'}      = $self->safe_uuid unless defined $self->{'uuid'};
  $self->{'cache'}     = Pagesmith::Cache->new( 'session', "$self->{'type'}|$self->{'uuid'}" ) unless $self->{'cache'};
  $self->touch;
  $self->_initialize( $params );
  return $self;
}

sub read_cookie {
  my $self = shift;
  my $cookie;
  my $rv = eval {
    my %cookie_jar = Apache2::Cookie->fetch( $self->r );
    $cookie = $cookie_jar{ $self->cookie_name };
  };
  return 0 if $EVAL_ERROR;
  return 0 unless $cookie && $cookie->value;
  my $details = $self->parse_cookie_value( $cookie );
  unless( $details->{'uuid'} ) { ## This is a broken cookie so "remove" it!
    $self->clear_cookie;
    $self->cache->unset;
    return 0;
  }
  $self->{'uuid'}      = $details->{'uuid'};
  $self->{'permanent'} = $details->{'permanent'};
  $self->{'ip'}        = $details->{'ip'};
  my $now = time;
  if( $now > $details->{'expiry_time'} ) {
    $self->clear_cookie;
    $self->cache->unset;
    return 0;
  }

  if( $now > $details->{'refresh_time'} ) {
    $self->touch;
    $self->write_cookie;
    $self->cache->touch( $self->{'expiry_time'} );

  }
  return 1;
}

sub encrypt {
  my( $self, $value, $serialize ) = @_;
  $value = $self->json_encode( $value ) if $serialize;
  return safe_base64_encode( $self->cipher->encrypt( $value ) );
}

sub decrypt {
  my( $self, $str, $serialize ) = @_;
  return unless $str;
  my $value;
  my $rv = eval {
    $value = $self->cipher->decrypt( safe_base64_decode( $str ) );
    $value = $self->json_decode( $value ) if $serialize;
  };
  return $value;
}

sub cipher {
  my $self = shift;
  $self->{'cipher'} ||= Crypt::CBC->new(
    '-key'    => $self->{'cookie_token'},
    '-cipher' => 'Blowfish',
    '-header' => 'randomiv', ## Make this compatible with PHP Crypt::CBC
  );
  return $self->{'cipher'};
}

sub generate_cookie_value {
  my $self = shift;
  return $self->encrypt(
    join q( ), $self->{'permanent'}, $self->{'uuid'}, $self->{'refresh_time'}, $self->{'expiry_time'}, $self->{'ip'},
  );
}

sub parse_cookie_value {
  my( $self, $cookie ) = @_;

  my $string = $self->decrypt( $cookie->value );
  return {} unless defined $string;
  my( $perm, $uuid, $refresh, $expiry, $ip ) = split m{\s}mxs, $string;
  return {} unless $uuid;
  return {(
    'permanent'    => $perm,
    'uuid'         => $uuid,
    'refresh_time' => $refresh,
    'expiry_time'  => $expiry,
    'ip'           => $ip,
  )};
}

1;
