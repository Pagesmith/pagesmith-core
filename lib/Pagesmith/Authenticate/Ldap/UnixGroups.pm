package Pagesmith::Authenticate::Ldap::UnixGroups;

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

use base qw(Pagesmith::Authenticate::Ldap);

use Const::Fast qw(const);
const my $GROUP_INDEX => 3;

sub authenticate {
  my( $self, $username, $pass, $parts ) = @_;
  my $details = $self->SUPER::authenticate( $username, $pass, $parts );
  if( $details->{'ldap_id'} ) {
    my $res = $self->run_cmd( ['groups', $details->{'ldap_id'}] );
    ( my $groups = $res->{'stdout'}[0] ) =~ s{\A.*?:\s+}{}mxs;
    my %groups = map { ($_=>1) } split m{\s+}mxs, $groups;
    $groups{ [getgrgid [getpwnam]->[$GROUP_INDEX]]->[0] }=1;
    push @{$details->{'groups'}}, map { "unix:$_" } sort keys %groups;
  }
  return $details;
}

1;
