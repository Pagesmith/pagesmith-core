package Pagesmith::Action::Shibboleth;

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

use Net::OpenID::Consumer;
use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);

use Pagesmith::Utils::FormObjectCreator;
use LWP::UserAgent;
use Pagesmith::Config;
use Pagesmith::Session::User;

sub run {
  my $self  = shift;
  return $self->html->wrap('TEST','<% Developer_Information %>')->ok;
}

1;
