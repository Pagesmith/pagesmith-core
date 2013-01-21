package Pagesmith::Adaptor::Generic::Wtcccuser;

## Adaptor for comments database
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

use base qw(Pagesmith::Adaptor::Generic);
use Pagesmith::Object::Wtcccuser;

use Readonly qw(Readonly);
Readonly my $DEFAULT_AUTHMETHOD = 999;

sub new {
  my( $class, $db_info, $r ) = @_;
  my $self = $class->SUPER::new( $db_info, $r );
  bless $self, $class;

  ##no critic(ProhibitLongChainsOfMethodCalls)
  $self
    ->set_table_name( 'sso_user' )
    ->set_type( 'Wtcccuser' )
    ->set_code( 'username' )
    ->set_sort_order( 'username', 'realname' );
  ##use critic(ProhibitLongChainsOfMethodCalls) 
  return $self;
}

####

sub get {
## Return a wtccc user if that account exists
#@param (self, userid)
#@return (Pagesmith::Object::Wtcccuser)
  my ($self,$userid) = @_;
  return unless $userid;

  ##no critic (ImplicitNewlines)
  my $hashref = $self->row_hash(
    'select username, password, realname, created, modified, ipaddr, authtype, addedby, note, email
       from '.$self->table_name.'
      where email = ?',
    $userid,
  );
  ##use critic (ImplicitNewlines)
  if ($hashref) {
    my $user = Pagesmith::Object::Wtcccuser->new( $self, {'objdata' => $hashref} );
    $self->initialise_object($user);
    # map values from database back to object
    $user->set_updated_at( $user->get('modified') );
    $user->set_created_at( $user->get('created') );
    $user->set_created_by( $user->get('addedby') );
    $user->set_ip(         $user->get('ipaddr') );

    return $user;
  }
}

sub get_all {
  my ($self,$userid) = @_;
  return unless $userid;

  my $array = $self->all_hash('select username from '.$self->table_name);
  if ($array) {
    return $array;
  }
}

sub create { # create from hashref
  my ($self, $hashref) = @_;
  if (ref $hashref) {
##
##  return Pagesmith::Object::Generic->new( $self, @pars );
##
    my $user = Pagesmith::Object::Wtcccuser->new( $self, {'objdata' => $hashref} );
    $self->initialise_object($user);
    return $user;
  }
  return;
}

sub update_password {
## Update the users password in the database
#@param (self, $object, new password)
#@return 1 for success
  my ($self,$user,$new_password) = @_;
  my $id = $user->get('username');
  return unless $id;
  return $self->query('UPDATE '.$self->table_name.' SET password = SHA1(?), modified = NOW() WHERE username = ? LIMIT 1',$new_password,$id);
}
sub update {
  my ($self,$user) = @_;
  my $id = $user->get('username');
#warn "username is $id";
  return unless $id;
  return $self->query('UPDATE '.$self->table_name.' SET realname = ?, note = ?, modified = NOW() WHERE username = ? LIMIT 1',$user->get('realname'),$user->get('note'),$id);
}

sub create_account {
## Create a new user in the account (ie; like store) but with duplicate protection.
#@param (self, $object)
  my ($self,$user) = @_;
  return unless $user->get('userid');

  # ensure is a NEW account
  my $hashref = $self->row_hash(
                                'select username from '.$self->table_name.' where email = ?', $user->get('userid'),
                               );
  return if $hashref;

  # and finally...
  ##no critic qw(ImplicitNewlines) 
  return $self->query('INSERT INTO '.$self->table_name
                     .'        SET    username,   password,             realname, created, modified,
                                        ipaddr,  authtype,       addedby,              note,              email
                       VALUES                ?,               SHA1(?),                     ?,   NOW(),    NOW(),
                                             ?,         ?,             ?,                 ?,                 ?',
                         $user->get('username'), $user->get('password'), $user->get('realname'),
                                  $user->{'ip'}, $DEFAULT_AUTHMETHOD, $self->user(), $user->get('note'), $user->get('email') );
}

sub delete_account {
## disable a users account (terrible version)
#@param (self, $object)
  my ($self,$user) = @_;
  return unless $user->get('userid');
  my $hashref = $self->row_hash(
    'update'.$self->table_name.q( set username = ?, password = 'xxxx', modified = NOW() where email = ?),
    'DISABLED:'.$user->get('userid').q(:),$user->get('userid'),
  );
  return 1 if $hashref;
  return;
}

# connect_to_db
# Setup self so connect_to_db can work
# $self->{'_dsn'}, $self->{'_dbuser'}, $self->{'_dbpass'}, $self->{'_dbopts'}
#  return $self->get_connection('');
sub connection_pars {
  return 'wtccc';
}
sub user_t {
  return 'users';
}

## NB: none of this stuff has been tested!!!

# Decide whether user/password combo is correct
sub is_valid {
  my ($self,$user,$password) = @_;
  my @results = $self->row('SELECT username FROM '.$self->user_t.' WHERE username = ? AND password = SHA1(?) LIMIT 1',$user->get('userid'),$password);
  return 1 if @results;
  return;
}

sub initialise_object {
  my ($self, $user) = @_;
  if( exists $self->{'_r'} && $self->{'_r'} ) {
    $user->set_ip(
      $self->{'_r'}->headers_in->{'X-Forwarded-For'} ||
      $self->{'_r'}->connection->remote_ip,
    ) unless defined $user->ip;
    $user->set_useragent( $self->{'_r'}->headers_in->{'User-Agent'} || q(--) );
  }

  $user->set_updated_by( $self->user );
  $user->set_updated_at( $user->now );

  $user->set_created_by( $self->user );
  $user->set_created_at( $user->now );
  return $self;
}


1;
