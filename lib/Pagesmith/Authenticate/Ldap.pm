package Pagesmith::Authenticate::Ldap;

## Authenticate using Ldap
## Author         : mw6
## Maintainer     : mw6
## Created        : 2010-11-05
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use List::MoreUtils qw(all);
use Net::LDAP;

use base qw(Pagesmith::Authenticate);

sub new {
  my( $class, $conf ) = @_;
  my $self = {
    'id'            => $conf->{'id'}||'uid',
    'base'          => $conf->{'base'},
    'server'        => $conf->{'server'},
    'name_patterns' => $conf->{'name'} || [qw(cn)],
    'ldap_entries'     => {},
    'ldap'          => undef,
    'groups'        => exists $conf->{'groups'} ? $conf->{'groups'} : {},
  };
  bless $self, $class;
  return $self;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub server {
  my $self = shift;
  return $self->{'server'};
}

sub base {
  my $self = shift;
  return $self->{'base'};
}

sub name_patterns {
  my $self = shift;
  return @{ $self->{'name_patterns'} };
}

sub ldap {
  my $self = shift;
  return $self->{'ldap'} ||= Net::LDAP->new( $self->server );
}

sub authenticate {
  my( $self, $username, $pass, $parts ) = @_;

  my $uid = $parts->[0];
  my $msg = $self->ldap->bind(
    (sprintf '%s=%s,%s', $self->id, $uid, $self->base ),
    'password' => $pass,
  );
  return {} unless $msg->code == 0;
  my $e = $self->_get_ldap_entry( \$uid );
  return {(
    'id'      => $username,
    'ldap_id' => $uid,
    'name'    => $self->realname( $uid ),
    'groups'  => $self->user_groups( $uid ),
  )};
}

sub _get_ldap_entry {
  my( $self, $uid_ref ) = @_;
  unless( exists $self->{'ldap_entries'}{${$uid_ref}} ) {
    # if no realname is present, we can fetch it from LDAP
    my $result = $self->ldap->search(
      'base'   => $self->base,
      'filter' => $self->id.q(=).${$uid_ref},
    );
    if($result) {
      my @e = $result->entries();
      if( @e ) {
        my ($t_uid) = $e[0]->get_value($self->id);
        ${$uid_ref} = $t_uid if ${$uid_ref};
        $self->{'ldap_entries'}{${$uid_ref}} = { 'raw' => $e[0] };
      }
    }
  }
  return $self->{'ldap_entries'}{${$uid_ref}};
}

sub realname {
  my( $self, $uid ) = @_;
  my $e = $self->_get_ldap_entry( \$uid );
  return q() unless $e;
  return $e->{'real_name'} if exists $e->{'real_name'};

  foreach my $pattern ( $self->name_patterns ) {
    my @parts = map { $e->{'raw'}->get_value($_) } split m{\s+}mxs, $pattern;
    next unless all { $_ } @parts;
    return $e->{'real_name'} = join q( ), @parts;
  }
  return $self->{'real_name'} = $uid;
}

1;
