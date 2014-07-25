package Pagesmith::Action::Shibboleth;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

use base qw(Pagesmith::Action::OAuth2);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use Const::Fast qw(const);

use Net::OpenID::Consumer;
use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);

use Pagesmith::Utils::FormObjectCreator;
use LWP::UserAgent;
use Pagesmith::Config;
use Pagesmith::Session::User;

sub run {
  my $self  = shift;
  my $form_code = $self->next_path_info;
  return $self->error( 'Unable to login user, erroneous URL' ) unless $form_code;
  my $form = Pagesmith::Utils::FormObjectCreator
    ->new( $self->r, $self->apr )
    ->form_from_code( $form_code );
  return $self->error( 'Unable to login user, erroneous URL' ) unless $form;
  return $self->error( 'Unable to login user' ) unless $self->create_session;
  return $self->redirect( $form->destroy_object->attribute('ref') );
}

sub create_session {
  my ( $self, $user_info, $system_key ) = @_;
  $self->r->subprocess_env();
  $self->dumper( \%ENV );
  return unless exists $ENV{'eppn'};
  my $user_details = {
    'method' => 'Shibboleth::'.$ENV{'Shib-Identity-Provider'},
    'id'     => exists $ENV{'uid'} ? $ENV{'uid'} : $ENV{'eppn'},
    'email'  => $ENV{'eppn'},
    'name'   => exists $ENV{'cn'}                             ? $ENV{'cn'}
              : exists $ENV{'displayName'}                    ? $ENV{'displayName'}
              : exists $ENV{'sn'} && exists $ENV{'givenName'} ? "$ENV{'givenName'} $ENV{'sn'}"
              : $ENV{'eppn'},
  };
  $self->dumper( $user_details );
  Pagesmith::Session::User->new( $self->r )->initialize($user_details)->store->write_cookie if $user_details->{'email'};
  return 1;
}

1;
