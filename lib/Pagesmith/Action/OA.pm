package Pagesmith::Action::OA;

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

use Apache2::Const qw(HTTP_METHOD_NOT_ALLOWED);
use Const::Fast qw(const);
use Pagesmith::Core qw(safe_base64_encode safe_base64_decode);
use Crypt::CBC;
use List::MoreUtils qw(all);

const my $HOUR => 3_600;
const my $SECRET => 'Ru4?id#0$c4R'; ## no critic (InterpolationOfMetachars)

const my $MESSAGES => {
  'incompatible redirect' => 'The configuration of the application precludes returing to the requested URL',
  'no state string'       => 'The configuraiton of the application requires a state string to be passed',
  'unknown scope'         => 'The application is requesting an unknown scope',
};

use base qw(Pagesmith::Action Pagesmith::Support::OAuth2);

sub run {
  my $self = shift;
  my $meth = 'run_'.($self->next_path_info);

  return $self->$meth if $self->can( $meth );

  return $self->no_content;
}

sub run_info {
  my $self = shift;

  my $to_dec = $self->cipher( $SECRET )->decrypt( safe_base64_decode($self->param('access_token')) );
  my($K,$V) = split m{[ ]}mxs, $to_dec, 2;
  my $ca = $self->adaptor( 'Client' );
  my $client = $ca->fetch_client( $K );
  my $c = $self->cipher( $client->get_salt );
  my $t;
  my $rv = eval { $t = $c->decrypt( $V ); };
  my @details = split m{[ ]}mxs, $c->decrypt( $V );
  return $self->not_found unless @detials;

  return $self->not_found if $expiry < time;

  ## Now we have to get user information about the user who's email address etc we have just had passed!
  ## As we don't have access to the session now we will need to go off and make the appropriate requests
  ## to our built in login code - either via ldap OR via user database!

  return $self->json_print( { 'email' => $user->get_username } );
}

sub oauth_error_page {
  my ( $self, $msg ) = @_;
  $msg = $MESSAGES->{$msg} if exists $MESSAGES->{$msg};
  return $self->html->wrap( 'OAuth2 error', sprintf '<p>%s</p>', $msg )->ok;
}

## no critic (ExcessComplexity)
sub run_auth {
  my $self = shift;

## Process the input....

  my $client_id       = $self->trim_param( 'client_id'      )||q();
  my $response_type   = $self->trim_param( 'response_type'  )||q();
     $response_type   = 'code' unless $response_type eq 'token';
  my $redirect_uri    = $self->trim_param( 'redirect_uri'   )||q();
  my ($path)          = split m{[?]}mxs, $redirect_uri;
  my $state           = $self->trim_param( 'state'          )||q();
  my $access_type     = $self->trim_param( 'access_type'    )||q();
     $access_type     = 'online' unless $access_type eq 'offline';

  my $approval_prompt = $self->trim_param( 'approval_prompt' )||q();
     $approval_prompt = 'auto' unless $approval_prompt eq 'force';
  my $login_hint      = $self->trim_param( 'login_hint'     )||q();
  my @scopes          = split m{\s+}mxs, $self->trim_param( 'scope' )||q();

  ## check we know what the client id is...
## Get information about the client!
  my $ca = $self->adaptor( 'Client' );
  my $client = $ca->fetch_client_by_code( $client_id );

  return $self->oauth_error_page( 'unknown client' ) unless $client;

  ## validate redirect_uri against client_id;
  my $urls = $client->get_all_urls;
  my %url_hash = map { ($_->get_url => $_->get_type) } @{$urls||[]};
  return $self->oauth_error_page( 'incompatible redirect' ) unless exists $url_hash{$path} && $url_hash{$path} eq 'redirect';

  ## Now get information about Scopes....
  my $scopes          = $ca->get_other_adaptor( 'Scope' )->fetch_scopes;
  my %scope_hash      = map { $_->get_code => $_ } @{$scopes};
  my @valid_scopes    = grep { exists $scope_hash{$_} } @scopes;

  ## The site has requested a scope which we don't know about!
  return $self->oauth_error_page( 'unknown scope' ) if @valid_scopes != @scopes;

  ## Mimic google specific prompt stuff!

  ## Which sub-part of process are we currently going through?

  ## User is not logged in so we will display a standard login form
  unless( $self->user->logged_in ) { ## User is logged in?
    ## Create login form object.. and redirect to login page...
    return $self->redirect( $self->form( 'Login' )->update_attribute( 'ref', $self->r->unparsed_uri )->store->action_url_get ); ## no critic (LongChainsOfMethodCalls)
  }

  ## Lets see if we have a user in the database!?!
  my $ua = $ca->get_other_adaptor('User');
  my $oa_user = $ua->fetch_user_by_username( $self->user->username );
  ## No so we create a new user!
  unless( $oa_user ) {
    $oa_user = $ua->create;
    $oa_user->set_username( $self->user->username );
    $oa_user->set_uuid( $self->safe_uuid );
    $oa_user->store;
  }
  $self->oauth_error( 'cannot create user object' ) unless $oa_user->uid;

  ## Now we have a user!
  my $pa          = $ca->get_other_adaptor('Permission');
  my $permissions = $pa->get_permissions_by_user_client( $oa_user, $client );

  my %perm_hash = map { $_->{'scope_id'} => $_->{'granted'} } @{$permissions||[]};

  my %granted_scopes = map { ($_ => exists $perm_hash{$scope_hash{$_}->uid} ? $perm_hash{$scope_hash{$_}->uid} : q(-) ) } @scopes;

  my $request_permission = 1;
     $request_permission = 0 if all { $_ eq 'yes' } values %granted_scopes;
     $request_permission = 1 if $approval_prompt eq 'force';

  if( $request_permission ) {
    ## We now know we need to request permission (or have just requested it!)
    if( $self->param('oa_form' ) ) {
      my $form = $self->form_by_code( $self->param('oa_form') );
      if( $form && $form->attribute( 'redirect' ) eq 'stored' ) {
        ## Now we need to store the granted permissions!
        my %scope_list = split m{\s+}mxs, $form->attribute( 'scope_list' );
        foreach ( keys %scope_list ) {
          $pa->store( { 'client' => $client, 'user' => $oa_user, 'scope_id' => $_ } );
        }
      } else {
        return $self->oauth_error_page( 'no permissions granted' );
      }
    } else {
      ## no critic (LongChainsOfMethodCalls)
      return $self->redirect( $self->form( 'OA' )
        ->update_attribute( 'ref', $self->r->unparsed_uri )
        ->add_attribute( 'client_id', $client->uid )
        ->add_attribute( 'scope_list', join q( ), map { sprintf '%d %s', $scope_hash{$_}->uid, $granted_scopes{$_} } @scopes )
        ->store
        ->action_url_get );
    }
  }
  my $expiry = time + $HOUR;
  if( $response_type eq 'token' ) {
  ## Finally we are logged in and we have given permission... Now we need to create the
  ## authentication_code
    my $hash = sprintf 'access_token=%s&token_type=Bearer&expires_in=%d',
      $self->generate_access_token({
        'client'    => $client,
        'user_id'   => $oa_user,
        'scope_ids' => [ map { $scope_hash{$_}->uid } @scopes ],
        'expiry'    => $expiry,
      }),
      $expiry-time;
    $hash .= sprintf '&state=%s', $state;
    return $self->redirect( $redirect_uri.q(#),$hash );
  } else {
    my $uuid = $self->safe_uuid;
    my $data_to_store = join q( ),
      $client->get_secret,
      $state||q(-),
      $uuid,
      $access_type eq 'offline' ? 1 : 0,
      $client->uid,
      $oa_user->uid,
      $expiry,
      map { $scope_hash{$_}->uid } @scopes;
    my $ciph = $self->cipher( $client->get_salt );
    my $code = $uuid .q(|). safe_base64_encode( $ciph->encrypt( $data_to_store ) );
       $code =~ s{\s+}{}mxsg;
    my $ret_url = sprintf '%s?state=%s&code=%s', $redirect_uri, $state, $code;
    return $self->redirect( $ret_url );
  }
  ## Redirect....
}
## use critic
sub cipher {
  my ( $self, $key ) = @_;
  return $self->{'ciphers'}{$key} ||= Crypt::CBC->new(
    '-key'     => $key,
    '-cipher'  => 'Blowfish',
    '-header'  => 'randomiv', ## Make this compactible with PHP Crypt::CBC
  );
}

sub generate_access_token {
  my( $self, $params ) = @_;
    $params->{'client'}->uid,
  my $to_encrypt = join q( ),
    $params->{'expiry'},
    $params->{'user'}->get_uuid,
    @{$params->{'scope_ids'}||[]};
  my $ciph = $self->cipher( $params->{'client'}->get_salt );
  $to_encrypt = $params->{'client'}->uid.q( ).
    $ciph->encrypt( $to_encrypt );
  ( my $token = safe_base64_encode($self->cipher( $SECRET )->encrypt( $to_encrypt ) ) ) =~ s{\s+}{}mxs;
  return $token;
}

sub run_access_token {
  my $self = shift;
  return HTTP_METHOD_NOT_ALLOWED unless $self->is_post;
  my $client_id     = $self->param( 'client_id' );
  my $client_secret = $self->param( 'client_secret' );
  my $code          = $self->param( 'code' );
  my $grant_type    = $self->param( 'grant_type' );
  my $redirect_uri  = $self->param( 'redirect_uri'   )||q();

  my $ca = $self->adaptor( 'Client' );
  my $client = $ca->fetch_client_by_code( $client_id );
  return $self->not_found unless $client;
  return $self->not_found unless $client->get_secret eq $client_secret;

  ## Test URL
  my ($path) = split m{[?]}mxs, $redirect_uri;
  my $urls = $client->get_all_urls;
  my %hash = map { ($_->get_url => $_->get_type) } @{$urls};
  return $self->not_found unless exists $hash{$path} && $hash{$path} eq 'redirect';

  my ($uuid,$check) = split m{[|]}mxs, $code;
  my $ciph = $self->cipher( $client->get_salt );
  my ($ch_secret, $ch_state, $ch_uuid, $access_type, $client_uid, $user_uid, $expiry, @scopes ) = split m{\s+}mxs,
    $ciph->decrypt( safe_base64_decode( $check ) );

  my $ua = $ca->get_other_adaptor('User');
  my $oa_user = $ua->fetch_user( $user_uid );

  if( $expiry &&
    $uuid eq $ch_uuid &&
    $client_uid eq $client->uid &&
    $ch_secret eq $client->get_secret &&
    $expiry <= time &&
    @scopes ) {
    my $access_token = $self->generate_access_token({
      'client'    => $client,
      'user'      => $oa_user,
      'scope_ids' => \@scopes,
      'expiry'    => $expiry,
    });

    my $values_to_return = {
      'access_token' => $access_token,
      'expires_in'   => $expiry - time,
      'token_type'   => 'Bearer',
    };

    if( $access_type ) {
      $values_to_return->{'refresh_token'} = 'fred';
    }
    return $self->json_print( $values_to_return );
  }
  return $self->not_found;
}



1;
