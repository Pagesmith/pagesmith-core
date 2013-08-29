package Pagesmith::Action::OpenId;

## Action to enable a user to authenticate against OpenId

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

use Net::OpenID::Consumer;
use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(proxy_url);
use Carp qw(carp);

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
  my( $self ) = @_;
  my $pch = Pagesmith::Config->new( { 'file' => 'external_auth', 'location' => 'site' } );
     $pch->load(1);
  return $pch->get( 'openid' );
}

sub run {
  my $self  = shift;
  my $state = $self->next_path_info;

  my $conf = $self->get_conf();
  return $self->no_content unless $conf && exists $conf->{'enabled'} && $conf->{'enabled'};

  my $redirect_url  = $self->base_url.'/action/OpenId/'.$state;
  my $form = Pagesmith::Utils::FormObjectCreator->new( $self->r, $self->apr )->form_from_code( $state );
  return $self->no_content unless $form;

  my $ua = LWP::UserAgent->new;
  my $proxy_url = proxy_url;
     $ua->proxy( ['http','https'], $proxy_url ) if $proxy_url;

  ## We need to split this three ways now...
  if( $self->is_post ) {
    ## Get open ID
    ## Send opend ID request....
    my $consumer_secret = $self->safe_uuid;
    $form->update_attribute( 'secret', $consumer_secret );
    $form->store;
    my $csr = Net::OpenID::Consumer->new(
      'ua'              => $ua,
      'consumer_secret' => $consumer_secret,
      'required_root'   => $self->base_url.q(/),
    );
    my $claimed_identity = $csr->claimed_identity( $self->param( 'url' ) );
    return $self->redirect( $redirect_url ) unless $claimed_identity;
    $claimed_identity->set_extension_args( 'http://openid.net/extensions/sreg/1.1',{
      'required'        => 'email,fullname',
      'optional'        => 'nickname',
      'policy_url'      => $self->base_url.'/legal/',
    });
    $claimed_identity->set_extension_args( 'http://openid.net/srv/ax/1.0',{
      'mode'            => 'fetch_request',
      'type.user'       => 'http://axschema.org/namePerson/friendly',
      'type.name'       => 'http://axschema.org/namePerson',
      'type.firstname'  => 'http://axschema.org/namePerson/first',
      'type.lastname'   => 'http://axschema.org/namePerson/last',
      'type.email'      => 'http://axschema.org/contact/email',
      'required'        => 'email,lastname,firstname',
      'if_available'    => 'name,user',
    });
    my $check_url = $claimed_identity->check_url(
      'return_to'  => "$redirect_url/callback",
      'trust_root' => $self->base_url,
      'delayed_return' => 1,
    );
    my @extra = qw();
    return $self->redirect( $check_url );
  }

  ## We have a get!
  return $self->no_content unless $self->path_info && $self->next_path_info eq 'callback';

  ## This is the call back
  my $consumer_secret = $form->attribute( 'secret' );
  my $csr = Net::OpenID::Consumer->new(
    'ua'              => $ua,
    'args'            => $self->apr,
    'consumer_secret' => $consumer_secret,
    'required_root'   => $self->base_url.q(/),
  );
  my $val;
  $csr->handle_server_response(
    'not_openid' => sub {
      $val = $self->redirect( $redirect_url ); ## broken $csr
    },
    'setup_needed' => sub {
      $val = $self->redirect( $csr->user_setup_url ); # (OpenID 1) redirect/link/popup user to $csr->user_setup_url
                                                      # (OpenID 2) retry request in checkid_setup mode - already done!
    },
    'cancelled' => sub {
      $val = $self->redirect( $form->destroy_object->attribute('ref') ); ## Go back to previous page!
    },
    'verified' => sub {
      my $vident = shift;
      $val = $self->create_session( $vident )->html->redirect( $form->destroy_object->attribute('ref') ); ## Go back to previous page!
    },
    'error' => sub {
      carp $csr->err;
      $val = $self->redirect( $redirect_url ); ## $csr->err;
    },
  );
  return $val if defined $val;
  ## Shouldn't really get here!
  return $self->redirect( $form->destroy_object->attribute('ref') ); ## Go back to previous page!
}

sub create_session {
  my ( $self, $vident ) = @_;
  ## no critic (LongChainsOfMethodCalls)
  my $details = { 'email' => undef, 'name' => undef };
  my $sreg_fields = $vident->extension_fields( 'http://openid.net/extensions/sreg/1.1' );
  my $ax_fields   = $vident->extension_fields( 'http://openid.net/srv/ax/1.0' );
  my $email = exists $sreg_fields->{'email'}          ? $sreg_fields->{'email'} :
              exists $ax_fields->{'value.email'}      ? $ax_fields->{'value.email'} :
              q();
  my $name  = exists $sreg_fields->{'fullname'}       ? $sreg_fields->{'fullname'} :
              exists $ax_fields->{'value.name'}       ? $ax_fields->{'value.name'} :
              exists $ax_fields->{'value.firstname'}  ? $ax_fields->{'value.firstname'}.q( ).($ax_fields->{'value.lastname'}||q()) :
              $vident->display || $vident->url; ## Default to something based on URL....
  Pagesmith::Session::User->new( $self->r )->initialize({
    'username' => $email || $vident->url,
    'name'     => $name,
    'opend_id' => $vident->url, ## This should be unique!
    'method'   => 'OpenID',
  })->store->write_cookie;
  return $self;
}
1;
