package Pagesmith::MyForm::Login;

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

use Readonly qw(Readonly);
Readonly my $MAX_FAILURES  => 3;

use base qw(Pagesmith::MyForm);
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

  my $pch = Pagesmith::Config->new( { 'file' => 'oauth2', 'location' => 'site' } );
  $self->{'oauth_data'} ||= $pch->load(1)->get;
  my $html ||= join q(),
    map { sprintf '<li><a href="/action/OAuth2/%s/%s">%s</li>', $_, $self->code, $self->{'oauth_data'}{$_}{'name'}||$_  }
    sort grep { exists $self->{'oauth_data'}{$_}{'enabled'} && $self->{'oauth_data'}{$_}{'enabled'} } keys %{$self->{'oauth_data'}};

  return q() unless $html;
  return sprintf q(<div class="panel"><h3>External logins</h3><ul>%s</ul></div>), $html;
}

sub initialize_form {
  my $self = shift;
  ## Set up the form...
  ## no critic (LongChainsOfMethodCalls)
  my $ret = $self->attribute( 'ref' )||q();
  $ret =~ s{\Ahttps?://[^/]+/}{/}mxs;
  $self->set_title( 'Login' )
       ->set_secure()
       ->add_class(          'form',     'check' )          # Javascript validation is enabled
       ->add_class(          'form',     'cancel_quietly' ) # Cancel doens't throw warning!
       ->add_class(          'section',  'panel' )          # Form sections are wrapped in panels
       ->add_class(          'layout',   'fifty50' )        # Centre the form object
       ->add_form_attribute( 'id',       'login' )
       ->add_form_attribute( 'method',   'post' )
       ->set_option(         'validate_before_next' )
       ->set_option(         'cancel_button' )
       ->set_option(         'no_reset', )
       ->set_navigation_path( $ret )
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
      $self->add( 'Password', "p$id" )->set_caption('Password')->set_do_not_store;
      $self->add( 'CheckBox', 'remember_me' )->remove_layout('eighty20')->set_optional();
      $self->add( { 'type' => 'Information', 'caption' => 'Please note we use cookies to identify your user, and by logging in you accept that we will write a cookie to your computer.' } );
  $self->add_redirect_stage( );

  $self->add_error_stage( 'unknown_user' )->set_back( 'Try again' )->set_back_stage( 0 );
    $self->add_raw_section( '<% File /core/inc/forms/unknown_user.inc %>', 'Unable to log in' );

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

  return $self->set_stage_by_name( 'unknown_user' ) if $self->attribute( 'failures' ) >= $MAX_FAILURES;

  return unless $user_element->value && $pass_element->value;
  ## We need to validate the user and password to see if we recognise them!
  my $webuser  = Pagesmith::Utils::Authenticate->new({
    'user'     => $user_element->value,
    'password' => $pass_element->value,
  });

  my $msg = $webuser->check_authentication;

  ## No message - successful login!
  return $self->{ 'user_session_data' } = $webuser->details unless $msg;

  ## If the msg was system failure - go to the system failure page
  return $self->set_stage_by_name( 'system_error' ) if $msg eq 'System failure' ;

  ## We had a message so invalidate username and password fields
  $user_element->set_invalid; ## Set these both as invalid
  $pass_element->set_invalid; ## Set these both as invalid

  $self->update_attribute( 'failures', $self->attribute( 'failures' ) + 1 );
  if( $self->attribute( 'failures' ) >= $MAX_FAILURES ) {
    $self->set_stage_by_name( 'unknown_user' );
  }
  return;
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
