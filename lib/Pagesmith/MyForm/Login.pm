package Pagesmith::MyForm::Login;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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

## Login form element
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
const my $MAX_FAILURES  => 3;
const my $SLEEP_FACTOR  => 2;

use base qw(Pagesmith::MyForm Pagesmith::SecureSupport);
use Pagesmith::Utils::Authenticate;
use Pagesmith::Core qw(safe_base64_encode);
use Pagesmith::Session::User;
use Pagesmith::Config;

## All MyForm objects are required to define a number of methods
##
## fetch_object    -> getting the attached object
##                    how to get an object out of the database to attach to the
##                    form - this is the object that we will be
##                    creating/editting
## initialize_form -> setting up the elements of the form
##                    this is done after the object is fetched so can depend
##                    on the current state of the underlying object
## submit_form     -> what to do when the user finally submits the form
##                    this will usually generate an object/update an existing
##                    object

sub render_extra {
  my $self = shift;

  my $pch = Pagesmith::Config->new( { 'file' => 'external_auth', 'location' => 'site' } )->load(1);

## Is OAUTH2 enabled?

  my $oauth = $pch->get( 'oauth2' );

  my @panels;
  my $c = $self->code;

  push @panels, sprintf '<div class="col2">%s</div>', $self->panel( sprintf
    q(<h3>Can't login</h3>
      <h4>Register</h4>
      <p class="wide-lines">
        If you do not already have an account you
        can <a class="btt" href="/users/Register/%s">register</a> for one,
        or use one of the alternative login methods
        below.
      </p>
      <h4>Forgot password</h4>
      <p class="wide-lines">
        If you have forgotten your password follow this
        link to <a class="btt" href="/users/ForgotPassword/%s">reset your password</a>
      </p>), $c, $c );
  my @html = map { sprintf
      '<li><a href="/action/OAuth2/%s/%s"><img src="/core/gfx/blank.gif" class="login-button login-%s" />... %s credentials</a></li>',
      $_, $c, $oauth->{$_}{'type'}, $oauth->{$_}{'name'}||$_  }
    sort grep { exists $oauth->{$_}{'enabled'} && $oauth->{$_}{'enabled'} }
    keys %{$oauth};

## Is shibboleth enabled?

  if( $pch->get( 'shibboleth', 'enabled' ) ) {
    push @html, sprintf '<li><a href="/action/Shibboleth/%s"><img src="/core/gfx/blank.gif" class="login-button login-shib" />... shibboleth</a></li>', $c;
  }
  push @panels, sprintf '<div class="col1">%s</div>',$self->panel( '<h3>Login with...</h3><ul>',@html,'</h3>' ) if @html;

## Is openid enabled?
  ## no critic (ImplicitNewlines)
  if( $pch->get( 'openid', 'enabled' ) ) {
    push @panels, sprintf '<div class="col2">%s</div>', $self->panel( sprintf '
  <h3>Login with openID</h3>
  <form method="post" action="/action/OpenId/%s" class="check">
    <p class="c">
      <input type="text" id="url" name="url" class="openid _url required" value="%s" />
      <input type="submit" value="Go" />
    </p>
  </form>', $c, $self->param( 'url' )||q() );
  }
  ## use critic

## Return unless none-of-the-above are enabled..
  return join q(), @panels;
}

sub initialize_form {
  my $self = shift;
  ## Set up the form...
  ## no critic (LongChainsOfMethodCalls)
  my $ret = $self->attribute( 'ref' )||q();
  $ret =~ s{\Ahttps?://[^/]+/}{/}mxs;
  $self->set_title( 'Login' )
       ->set_secure
       ->add_class(          'form',     'check' )          # Javascript validation is enabled
       ->add_class(          'form',     'cancel_quietly' ) # Cancel doens't throw warning!
       ->add_class(          'section',  'panel' )          # Form sections are wrapped in panels
       ->add_class(          'layout',   'fifty50' )        # Centre the form object
       ->add_form_attribute( 'id',       'login' )
       ->add_form_attribute( 'method',   'post' )
       ->set_option(         'validate_before_next' )
       ->set_option(         'cancel_button' )
       ->set_option(         'no_reset' )
       ->set_navigation_path( $ret )
       ->set_expiry(         '1 hour' )                     # Expire form object 1 hour after any "setting" activity!
       ->set_no_progress
       ;
  ## use critic
  $self->add_attribute( 'failures', 0 );
  $self->force_form_code(); ## Need to do this so we definitely have an ID!
  ( my $id = $self->code ) =~ s{\W}{_}mxgs;

  ## Now add the elements
  $self->add_stage( 'Login' )->set_next('Login');
    $self->add_section( 'Login' );
      $self->add( 'Email',   'email' )->add_class( 'medium' );
      $self->add( 'Password', "p$id" )->set_caption('Password')->set_do_not_store->remove_class('_password'); ## no critic (LongChainsOfMethodCalls)
      $self->add( 'CheckBox', 'remember_me' )->remove_layout('eighty20')->set_optional();
      $self->add( { 'type' => 'Information', 'caption' => 'Please note we use cookies to identify your user, and by logging in you accept that we will write a cookie to your computer.' } );

  $self->add_redirect_stage( );

  $self->add_error_stage( 'unknown_user' )->set_back( 'Try again' )->set_back_stage( 0 );
    $self->add_raw_section( '<% File /core/inc/forms/unknown_user.inc %>', 'Unable to log in' );

  my $encrypted_em_addr = $self->encrypt_url( 'users', $self->element('email')->value );
  $self->add_error_stage( 'need_to_validate_email' )->set_back( 'Try again' )->set_back_stage( 0 );
    $self->add_raw_section( '<h3>You need to validate your email</h3>
      <p>When you registered your account an email was sent to the address you entered.
        Please check your inbox and follow the link in the email.</p>
      <p>If you have have not yet received this email (or deleted it) you
        can <a href="/users/InviteReminder/-'.$self->code.'">click here to resend this initial email</a></p>',
      'Unable to log in' );

  $self->add_error_stage( 'system_error' )->set_back( 'Try again' )->set_back_stage( 0 );
    $self->add_raw_section( '<% File /core/inc/forms/system_error.inc %>', 'Unable to log in' );

  return $self;
}

sub extra_validation {
  my $self = shift;

  ( my $id = $self->code ) =~ s{\W}{_}mxgs; ## The id for the password field is 'p'.****

  my $user_element  = $self->element( 'email' );
  my $pass_element  = $self->element( "p$id" );

  ## If we have more failures than the current max failures we will automatically show the unknown user error page!

  return $self->fail_user( $user_element, $pass_element ) if  $self->attribute( 'failures' ) >= $MAX_FAILURES;

  return unless $user_element->value && $pass_element->value;
  ## We need to validate the user and password to see if we recognise them!
  my $webuser  = Pagesmith::Utils::Authenticate->new({
    'user'     => $user_element->value,
    'password' => $pass_element->value,
  });

  my $msg = $webuser->check_authentication;

  ## No message - successful login!
  unless( $msg ) {
    if( $webuser->details->{'status'} eq 'active' ) {
      return $self->{ 'user_session_data' } = $webuser->details;
    }
    return $self->set_stage_by_name( 'unknown_user', 1 ) unless $webuser->details->{'status'} eq 'pending';
    $self->set_stage_by_name( 'need_to_validate_email', 1 );
    return;
  }
  ## If the msg was system failure - go to the system failure page
  return $self->set_stage_by_name( 'system_error', 1 ) if $msg eq 'System failure' ;
  return $self->fail_user( $user_element, $pass_element );
}

sub fail_user {
  my( $self, $user_element, $pass_element ) = @_;
  ## We had a message so invalidate username and password fields
  $user_element->set_invalid; ## Set these both as invalid
  $pass_element->set_invalid; ## Set these both as invalid

  $self->update_attribute( 'failures', $self->attribute( 'failures' ) + 1 );
  if( $self->attribute( 'failures' ) >= $MAX_FAILURES ) {
    sleep $self->attribute( 'failures' ) * $SLEEP_FACTOR;
    $self->set_stage_by_name( 'unknown_user' );
  }
  return;
}

sub on_goto {
  my( $self, $current_stage, $new_stage_id ) = @_;
  if( $new_stage_id == 0 ) {
    $self->set_stage( 0 );
  }
  return 1;
}

sub on_error { ## What should we do on an error stage!
  my( $self, $stage ) = @_;
  if( $stage->id eq 'unknown_user' ) {
    $self->update_attribute( 'failures', 0 )->store; ## Reset failure count...
  }
  return $self;
}

sub on_redirect {
  my( $self, $stage ) = @_;

  ## Create a new User session, then redirect to the login page...
  ## no critic (LongChainsOf)
  Pagesmith::Session::User->new( $self->r )->initialize(
    $self->{'user_session_data'},
    $self->element('remember_me')->value eq 'yes',
  )->store->write_cookie;
  $self->destroy_object; ## Remove entry from Cache!
  ## use critic
  return $self->attribute( 'ref' ) || $self->base_url( $self->r ).q(/);
}

1;
