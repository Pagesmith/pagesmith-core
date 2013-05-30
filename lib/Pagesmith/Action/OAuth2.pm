package Pagesmith::Action::OAuth2;

## Handles external links (e.g. publmed links)
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

use base qw(Pagesmith::Action);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use Const::Fast qw(const);

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Core qw(safe_base64_decode);
use URI::Escape qw(uri_escape_utf8);
use Pagesmith::Utils::FormObjectCreator;
use LWP::UserAgent;
use Pagesmith::Config;
use Pagesmith::Session::User;

sub error {
  my( $self, $reason, $form ) = @_;

  my @links = $form ? ( [ $form->attribute('ref'), 'Return to whence you came' ],
                        [ '/form/-'.$form->code,   'Return to login form'      ] )
                    : ( [ '/login',                'Go to login form'          ] )
                    ;

  return $self->html->wrap( 'Login failed',
    sprintf '<p>%s</p><ul>%s</ul>',
      $reason,
      join q(), map { sprintf '<li><a href="%s">%s</a></li>', @{$_} } @links,
  )->ok;
}

sub get_conf {
  my( $self, $key ) = @_;
  my $pch = Pagesmith::Config->new( { 'file' => 'external_auth', 'location' => 'site' } );
     $pch->load(1);
  return $pch->get( 'oauth2', $key );
}

sub send_to_oauth2_provider {
  my( $self, $redirect_url, $client_id, $conf ) = @_;
  my $form_code = $self->next_path_info;
  my $form = Pagesmith::Utils::FormObjectCreator
    ->new( $self->r, $self->apr )
    ->form_from_code( $form_code );
  return $self->error( 'Unable to authenticate user, erroneous URL' ) unless $form;
  ( my $scope = uri_escape_utf8($conf->{'scope'}) ) =~ s{%20}{+}mxsg;
  my $URL = sprintf '%s?client_id=%s&redirect_uri=%s&scope=%s&state=%s&response_type=code',
    $conf->{'get_code'}, $client_id, uri_escape_utf8($redirect_url), $scope, $form_code;
  printf {*STDERR} "URL: %s\n", $URL;
  return $self->redirect( $URL );
}

## no critic (ExcessComplexity)
sub run {
  my $self  = shift;
  my $system_key    = $self->next_path_info;
  my $redirect_url  = $self->base_url.'/action/OAuth2/'.$system_key;
  my $conf = $self->get_conf( $system_key );

  return $self->no_content unless $conf;
  return $self->no_content unless exists $conf->{'enabled'} && $conf->{'enabled'};

  my $client_id     = $conf->{'client_id'};
  my $client_secret = $conf->{'client_secret'};

  my ($domain) = split m{:}mxs, $self->r->headers_in->{'Host'};
  ($client_id,$client_secret) = @{$conf->{'sites'}{$domain}} if
    exists $conf->{'sites'} && exists $conf->{'sites'}{$domain};

  my $state = $self->param('state');

  return $self->send_to_oauth2_provider( $redirect_url, $client_id, $conf ) unless $state;

  my $form = Pagesmith::Utils::FormObjectCreator->new( $self->r, $self->apr )->form_from_code( $state );
  return $self->error( 'Unable to authenticate user, erroneous URL' ) unless $form;

  my $code  = $self->param('code')||q();
  return  $self->error( 'Unable to authenticate user', $form ) unless $code;

  ## Set up proxy....
  my $ua = LWP::UserAgent->new;
  my $proxy_url = get_config( 'ProxyURL' );
  $ua->proxy( ['http','https'], $proxy_url ) if $proxy_url;

  ## Retrieve the authentication token....
  my $resp = $ua->post(
    $conf->{'get_token'}, {
      'client_id'     => $client_id,
      'redirect_uri'  => $redirect_url,
      'client_secret' => $client_secret,
      'code'          => $code,
      'grant_type'    => 'authorization_code',
    } );
  my $token;
  if( $resp->is_success ) {
    if( q({) eq substr $resp->content, 0, 1 ) {
      my $token_info = eval { $self->json_decode( $resp->content ) };
      $token = $token_info->{'access_token'} if $token_info && ref $token_info eq 'HASH';
    } else {
      $token = $resp->content =~ m{access_token=([^&]+)}mxs ? $1 : q();
    }
  }

  return $self->error( 'Connection failed', $form ) unless $token;

  ## Now go off and get the user information... returns a JSON structure...
  $resp = $ua->get( $conf->{'get_userinfo'}.'?access_token='.$token );

  my $user_info = eval { $resp->is_success ? $self->json_decode( $resp->content ) : undef; };
  return $self->error( 'connection failed', $form ) unless $user_info && ref $user_info eq 'HASH';
  $user_info = $user_info->{'Profile'} if exists $user_info->{'Profile'};
  ## Create user session and write cookie...
  return $self->create_session( $user_info, $system_key )->redirect( $form->destroy_object->attribute('ref') );
}
## use critic

sub create_session {
  my ( $self, $user_info, $system_key ) = @_;
  my $user_details = {
    'method' => 'OAuth2::'.$system_key,
    'email'  => exists $user_info->{'email'}         ? $user_info->{'email'}
              : exists $user_info->{'PrimaryEmail'}  ? $user_info->{'PrimaryEmail'}
              : exists $user_info->{'emails'}        ? $user_info->{'emails'}{'account'}
              :                                        undef,
    'name'   => exists $user_info->{'name'}          ? $user_info->{'name'}
              : exists $user_info->{'Name'}          ? $user_info->{'Name'}
              :                                        undef,
    'id'     => exists $user_info->{'id'}            ? $user_info->{'id'}
              : exists $user_info->{'CustomerId'}    ? $user_info->{'CustomerId'}
              :                                        undef,
  };
  Pagesmith::Session::User->new( $self->r )->initialize($user_details)->store->write_cookie if $user_details->{'email'};
  return $self;
}
1;
