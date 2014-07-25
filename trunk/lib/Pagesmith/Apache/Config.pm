package Pagesmith::Apache::Config;

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

## Cofniguration from apache config files
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

use Apache2::Const qw(OK);
use Apache2::Module     ();
use Apache2::RequestRec ();
use Apache2::ServerUtil ();
use APR::Table ();
use English qw(-no_match_vars $PID);
use Time::HiRes qw(gettimeofday);
use Pagesmith::Cache::SQL;
use Pagesmith::Cache::File;
use Pagesmith::Cache::Memcache;
use Pagesmith::ConfigHash qw(set_r set_site_key data init_data set_key_root set_proxy_url set_proxy_noproxy);

use Const::Fast qw(const);
const my $BITS => 15;

sub child_init_handler {
  ##no critic (CallsToUnexportedSubs)
  my $cfg = Apache2::Module::get_config( 'Pagesmith::Apache::Params', Apache2::ServerUtil->server );

  ## Initialize the list of memcached servers, and options
  Pagesmith::Cache::Memcache::add_server( split m{,}mxs, $_, 2 ) foreach $cfg->mc_servers;
  Pagesmith::Cache::Memcache::add_option( split m{=}mxs, $_, 2 ) foreach $cfg->mc_options;
  ## Initialize the SQL cache settings (dsn/user/pass/options)
  Pagesmith::Cache::SQL::set_dsn( $cfg->sql_dsn )   if $cfg->sql_dsn;
  Pagesmith::Cache::SQL::set_user( $cfg->sql_user ) if $cfg->sql_user;
  Pagesmith::Cache::SQL::set_pass( $cfg->sql_pass ) if $cfg->sql_pass;
  Pagesmith::Cache::SQL::add_option( split m{=}mxs, $_, 2 ) foreach $cfg->sql_options;
  ## Initialize the file based system cache (root path/options)
  Pagesmith::Cache::File::set_path( $cfg->fs_path ) if $cfg->fs_path;
  Pagesmith::Cache::File::add_option( split m{=}mxs, $_, 2 ) foreach $cfg->fs_options;
  ##use critic (CallsToUnexportedSubs)

  init_data();
  set_key_root( $cfg->config_prefix );
  set_proxy_url( $cfg->proxy_url );
  set_proxy_noproxy( [$cfg->proxy_noproxy] );

  my( $t, $u ) = gettimeofday;
  my $seed = $t ^ $u ^ ($PID + ($PID << $BITS)); ## no critic (BitwiseOperators)
  srand $seed;
  return OK;
}

sub post_read_request_handler {
  ## Set up sitename!
  my $r = shift;
  set_r( $r );
  my $port = $r->prev ? $r->prev->get_server_port : $r->get_server_port;
  my $k = $port . q(.) . $r->hostname;

  set_site_key( $k );
  (data)->{ $k } ||= {};
  return OK;
}

1;
