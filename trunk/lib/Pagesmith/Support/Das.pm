package Pagesmith::Support::Das;

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

## Monitorus proxy!
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-13
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use LWP::Simple qw(get $ua);
use Time::HiRes qw(time);

use base qw(Pagesmith::Root);
use Pagesmith::Utils::Curl::Fetcher;
use Const::Fast qw(const);

const my $MAX_REQ       => 20;
const my $THREE_MINUTES => 180;
const my $FOUR_K        => 4_096;

my %valid_response_codes = (
  '200' => {qw(200 1)},
  '400' => {qw(400 1 401 1 402 1 403 1 405 1)},
  '404' => {qw(404 1)},
  '500' => {qw(500 1 501 1)},
);

my %expected = qw(
  entry_points DASEP features DASGFF sequence DASSEQUENCE
  ---- SOURCES sources SOURCES stylesheet DASSTYLE types DASTYPES
  alignment dasalignment structure dasstructure
);

sub get_sources {
  my( $self, $domain ) = @_;
  my $sources_markup = get "http://$domain/das/sources";
  my @urls;
  foreach ( split m{</SOURCE>}mxs, $sources_markup ) {
    my ($name)  = m{<SOURCE[^>]+uri="([^"]+)"}mxs;
    next unless $name;
    my ($query) = m{test_range="([^"]+)"}mxs;
       $query||=q();
    my @cap_urls    = m{<CAPABILITY[^>]+query_uri="([^"]+)"}mxsg;
    push @urls, sprintf '%s?%s=%s',
      $_,
      m{/(?:structure|alignment)\Z}mxs ? 'query' : 'segment',
      $query foreach @cap_urls;
  }
  return @urls;
}

## no critic (ExcessComplexity)
sub fetch_results {
  my( $self, $domain, @urls_to_test ) = @_;

  my $regex = sprintf 'http://%s/das/([^?]*)', join q([.]), split m{[.]}mxs, $domain;

  my $c     = Pagesmith::Utils::Curl::Fetcher->new->set_timeout( $THREE_MINUTES )->set_max_size( $FOUR_K );

  foreach ( 1..$MAX_REQ ) {
    last unless @urls_to_test;
    $c->new_request( shift @urls_to_test )->init;
  }

  my @results;

  while ($c->has_active) {
    if( $c->active_transfers == $c->active_handles ) {
      $c->short_sleep;
      next;
    }
    while( my $req = $c->next_request ) {
      my $url      = $req->url;
      my $rc       = $req->response->code || 0;
      my ($t)      = $url =~ m{$regex}mxs;
         $t        ||= 'DODGY SERVER';
      my ($s,$co)  = split m{/}mxs, $t;
      $co          ||= q(----);
      my $dc       = $req->response->header( 'X-Das-Status' ) || 0;
      my $servers  = join q(; ), map { m{https?://([^/]+)/}mxs ? $1 : q(??) } $req->response->header( 'X-DAS-RealUrl' );
      my $bdy      = $req->response->body || q();
      my ($type)   = $bdy =~ m{<(\w+)}mxs;
         $type   ||= q(###);
      $c->remove($req);

      push @results, {
        'error'       => $rc ne '200' || $dc ne '200' || !exists $expected{$co} || $type ne $expected{$co} || !exists $valid_response_codes{$rc}{$dc} ?
                         'X' : q(-),
        'error_http'  => $rc ne '200' ? 'HTTP' : q(-),
        'error_das'   => $dc ne '200' ? 'DAS'  : q(-),
        'error_resp'  => exists $expected{$co} ? ( $type eq ($expected{$co}||q(-)) ? q(-) : q(resp) ) : q(req),
        'error_code'  => exists $valid_response_codes{$rc}{$dc} ? q(-) : q(mismatch),
        'http_code'   => $rc,
        'das_code'    => $dc,
        'command'     => $co,
        'length'      => $req->response->size,
        'source'      => $s,
        'resp_type'   => $type,
        'servers'     => $servers,
        'duration'    => time - $req->start_time,
      };
      last unless @urls_to_test;
      $c->new_request( shift @urls_to_test )->init;
    }
  }
  return @results;
}
## use critic
1;
