package Pagesmith::Action::OAuth2;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

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
use Pagesmith::ConfigHash qw(proxy_url);
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

  my $error = $self->param('error')||q();

  ## What to do if the user cancels...
  return $self->redirect( '/form/-'.$state ) if $error;

  ## First time through this script there will be no state parameter
  ## So we need to redirect to create a state token and redirect to
  ## the oauth2 providers "get_code" url - the state is taken from
  ## the 2nd URL path parameter (which is the key to an active form
  ## object. The state is the code of the form object...
  return $self->send_to_oauth2_provider( $redirect_url, $client_id, $conf ) unless $state;

  ## Get the form object - and die if the form doesn't exist
  my $form = Pagesmith::Utils::FormObjectCreator->new( $self->r, $self->apr )->form_from_code( $state );
  return $self->error( 'Unable to authenticate user, erroneous URL' ) unless $form;

  ## We have not been redirected with a code response so again fail!
  my $code  = $self->param('code')||q();
  return  $self->error( 'Unable to authenticate user', $form ) unless $code;

  ## Set up proxy....
  my $ua = LWP::UserAgent->new;
  my $proxy_url = proxy_url;
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
  my $user_info;
  foreach ( split m{\s+}mxs, $conf->{'get_userinfo'} ) {
    my $atn = exists $conf->{'access_token_name' } ? $conf->{'access_token_name' } : 'access_token';
    $resp = $ua->get( "$_?$atn=$token" );
    $user_info = eval { $resp->is_success ? $self->json_decode( $resp->content ) : undef; };
  }
  return $self->error( 'connection failed', $form ) unless $user_info && ref $user_info eq 'HASH';
  my $details = $self->get_details( $user_info, $conf->{'details'} );
  ## Create user session and write cookie...
  return $self->create_session( $details, $system_key, $token, q() )->redirect( $form->destroy_object->attribute('ref') );
}
## use critic

sub get_details {
  my( $self, $user_info, $keys ) = @_;
  my $user_details = {};
  my $details_cache = {};
  foreach my $key ( keys {%{$keys}} ) {
    my @info_keys = split m{\s+}mxs, $keys->{$key};
    foreach my $info_key ( @info_keys ) {
      unless( exists $details_cache->{$info_key} ) {
        my $t = $user_info;
        foreach (split m{[.]}mxs, $info_key) {
          $t = $t->{$_};
        }
        $details_cache->{$info_key} = $t;
      }
    }
    $user_details->{$key} = join q( ), @{$details_cache}{@info_keys};
  }
  return $user_details;
}

sub create_session {
  my ( $self, $user_details, $system_key, $access_token, $refresh_token ) = @_;
  $user_details->{'method'}        = 'OAuth2::'.$system_key;
  $user_details->{'access_token'}  = $access_token;
  $user_details->{'refresh_token'} = $refresh_token if $refresh_token;
  Pagesmith::Session::User->new( $self->r )->initialize($user_details)->store->write_cookie;  ## no critic (LongChainsOfMethodCalls)
  return $self;
}
1;
