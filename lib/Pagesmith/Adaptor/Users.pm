package Pagesmith::Adaptor::Users;

## Adaptor for user database...
## Author         : js5
## Maintainer     : js5
## Created        : 2011-06-01
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Adaptor);

use Readonly qw(Readonly);

Readonly my $MAX_TRIES => 10;
Readonly my $CODE_LEN  =>  8;

use Pagesmith::Object::Users::Group;
use Pagesmith::Object::Users::User;

use Pagesmith::Utils::Bcrypt; # if you want to be able to update password (requires libcrypt-eksblowfish-perl + libcrypt-openssl-random-perl)

sub connection_pars {
  return 'users';
}

sub set_apikey {
  my( $self, $key ) = @_;
  my $details = $self->row_hash( 'select id,superkey from apikey where code = ? and active="yes"', $key );
  return unless $details;
  $self->{'_apikey_id'} ||= $details->{'id'};
  $self->{'_super'}     ||= $details->{'superkey'};
  return $self->{'_apikey_id'};
}

sub superkey {
  my $self = shift;
  return $self->{'_super'};
}

sub apikey_id {
  my $self = shift;
  return $self->{'_apikey_id'};
}

sub store_member {
## Store the user in the database
## NB: No password
  my ( $self, $member ) = @_;
  unless ( $member->created_at ) {
    $member->set_created_at($self->now);
  }
  ##no critic (ImplicitNewlines)
  return $self->insert(
   'insert ignore into user
                ( created_at, updated_at,      email,          name,          institute,          status_id)
          values( ?,          ?,               ?,              ?,             ?,                  ?       )',
   'user', 'id',
   $member->created_at, $member->created_at, $member->email, $member->name, $member->institute, $member->status_id );
  ##use critic (ImplicitNewlines)
}

sub change_member_password {
  my( $self, $member ) = @_;
  my $password = $member->password;
  my $encrypted_password = Pagesmith::Utils::Bcrypt->new({'username'=>$member->email,'password'=>$password})->encode_password();
  return $self->query('update user set password = ?, updated_at = ? where id = ?',
                                $encrypted_password,     $self->now,  $member->id, );
}

sub change_member_name {
  my( $self, $member ) = @_;
  return $self->query('update user set name = ?, updated_at = ? where id = ?',
                                  $member->name,     $self->now,  $member->id, );
}

sub change_member_institute {
  my( $self, $member ) = @_;
  return $self->query('update user set institute = ?, updated_at = ? where id = ?',
                                 $member->institute,     $self->now,  $member->id, );
}

sub change_member_status {
  my( $self, $member ) = @_;
  return $self->query('update user set status_id = ?, updated_at = ? where id = ?',
                                  $member->status_id,     $self->now,  $member->id, );
}

sub store_group {
  my( $self, $group ) = @_;
  if( $group->id ) {
    return if $self->sv( 'select id from usergroup where code = ?', $group->code );
    ## no critic (ImplicitNewlines)
    return $self->query(
      'insert into usergroup
          set (code,name,status,grouptype_id,created_at,updated_at)',
      'usergroup','id',
      $group->code, $group->name, $group->status,
      $group->grouptype_id, $self->now, $self->now,
    );
    ## use critic
  }
  return $self->query( 'update usergroup set code = ?, name = ?, status = ?, grouptype_id = ?, updated_at = ? where id = ?',
    $group->code, $group->name, $group->status,
    $group->grouptype_id, $self->now, $group->id,
  );
}

sub retrieve_group {

}

sub fetch_all_groups {
#@param (self)
  my ($self,@pars) = @_;
## no critic (ImplicitNewlines)
  if( $self->superkey ) {
    return  map { (Pagesmith::Object::Users::Group->new( $self, \%{$_} )) } @{ $self->all_hash(
      'select g.usergroup_id as id, g.code, g.name, g.description,
              g.created_at, g.updated_at,
              g.grouptype_id, gt.code as grouptype,
              g.status
         from usergroup as g,grouptype as gt
        where g.grouptype_id = gt.id',
    )} ;
  }
  return map { Pagesmith::Object::Users::Group->new( $self, \%{$_} ) } @{ $self->all_hash(
    'select g.usergroup_id as id, g.code, g.name, g.description,
            g.created_at, g.updated_at,
            g.grouptype_id, gt.code as grouptype,
            g.status
       from usergroup as g, grouptype as gt, usergroup_apikey as ga
      where g.grouptype_id = gt.id and g.usergroup_id = ga.usergroup_id and ga.apikey_id = ?',
    $self->apikey_id,
  )};
  ## use critic
}

sub fetch_group_by_id {

}

sub fetch_group_by_code {

}

sub fetch_user_by_id {

}

sub fetch_user_by_email {
  my( $self, @pars ) = @_;
  my $email = $pars[0];
  my $user = $self->row_hash('select user.*, s.code as status from user, status as s where email = ? and user.status_id = s.id',$email);
  if ('HASH' eq ref $user) {
    return Pagesmith::Object::Users::User->new( $self, $user );
  }
  return;
}

sub create_group {
#@param (self)
#@param (hashref)? Optional hashref of attributes
#@return (Pagesmith::Object::Users::Group)
## Create a new group object
  my( $self, @pars ) = @_;
  return Pagesmith::Object::Users::Group->new( $self, @pars );
}

sub create_user {
#@param (self)
#@param (hashref)? Optional hashref of attributes
#@return (Pagesmith::Object::Users::User)
## Create a new user object
  my( $self, @pars ) = @_;
  return Pagesmith::Object::Users::User->new( $self, @pars );
}

sub add_member_to_group {
  my( $self, $user, $group, $status ) = @_;
  my $now = $self->now;
  ## no critic (ImplicitNewlines)
  return 0+$self->query(
    'insert ignore into user_usergroup
        set user_id = ?, usergroup_id = ?, status = ?, created_at = ?, updated_at = ?',
    $user->id, $group->id, $status, $now, $now,
  );
  ## use critic
}

sub remove_member_from_group {
  my( $self, $user, $group ) = @_;
  ## no critic (ImplicitNewlines)
  return 0+$self->query(
    'delete from user_usergroup
      where user_id = ? and usergroup_id = ?',
    $user->id, $group->id,
  );
  ## use critic
}

sub change_member_status_in_group {
  my( $self, $user, $group, $status ) = @_;
  my $now = $self->now;
  ## no critic (ImplicitNewlines)
  return $self->query(
    'update user_usergroup
        set status = ?, updated_at = ?
      where user_id = ? and usergroup_id = ?',
    $status, $now, $user->id, $group->id,
  );
  ## use critic
}

sub get_member_group_status {
  my( $self, $user, $group ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->query(
    'select status
       from user_usergroup
        set user_id = ?, usergroup_id = ?',
    $user->id, $group->id,
  );
  ## use critic
}

sub get_groups_by_member {
  my( $self, $user ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash(
    'select g.usergroup_id as id, g.*,ug.status as member_status
       from usergroup as g, user_usergroup as ug
      where g.usergroup_id = ug.usergroup_id and ug.user_id = ?',
    $user->id,
  );
  ## use critic
}

sub get_members_by_group {
  my( $self, $group ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash(
    'select u.*,ug.status as member_status
       from user as u, user_usergroup as ug
      where u.id = ug.user_id and ug.usergroup_id = ?',
    $group->id,
  );
  ## use critic
}

sub get_active_groups_by_member {
  my( $self, $user ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash(
    'select distinct g.*,"active" as member_status
       from usergroup as g, user_usergroup as ug, usergroup_apikey as ua
      where g.id = ug.usergroup_id and ug.user_id = ? and
            ug.status="active" and g.id = ua.usergroup_id and
            ua.apikey_id = ?',
    $user->id, $self->apikey_id,
  );
  ## use critic
}

sub get_active_members_by_group {
  my( $self, $group ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash(
    'select u.*,"active" as member_status
       from user as u, user_usergroup as ug
      where u.id = ug.user_id and ug.usergroup_id = ? and
            ug.status="active"',
    $group->id,
  );
  ## use critic
}

1;

