package Pagesmith::Action::Das::Status;

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

use base qw(Pagesmith::Action::Das);
use List::MoreUtils qw(uniq);
use LWP::Simple qw(get $ua);
use Time::HiRes qw(time);

use Pagesmith::Utils::Curl::Fetcher;

use Const::Fast qw(const);
const my $MAX_REQ       => 20;
const my $THREE_MINUTES => 180;

my %valid_response_codes = (
  '200' => {qw(200 1)},
  '400' => {qw(400 1 401 1 402 1 403 1 405 1)},
  '404' => {qw(404 1)},
  '500' => {qw(500 1 501 1)},
);

my %expected = qw(entry_points DASEP features DASGFF sequence DASSEQUENCE ---- SOURCES sources SOURCES stylesheet DASSTYLE types DASTYPES);


sub get_sources {
  my( $self, $domain ) = @_;
  my $sources_markup = get "http://$domain/das/sources";
  my %sources;
  foreach ( split m{</SOURCE>}mxs, $sources_markup ) {
    my ($name)  = m{<SOURCE[^>]+uri="([^"]+)"}mxs;
    my ($query) = m{test_range="([^"]+)"}mxs;
       $query||=q();
    my @URLS    = m{<CAPABILITY[^>]+query_uri="([^"]+)"}mxsg;
    push @{$sources{$name}}, sprintf '%s?%s=%s',
      $_,
      m{alignment\Z}mxs ? 'query' : 'segment',
      $query foreach @URLS;
  }
  return map { @{$_} } values %sources;
}

## no critic (ExcessComplexity)
sub fetch_results {
  my( $self, $domain, @urls_to_test ) = @_;

  my $regex = sprintf 'http://%s/das/([^?]*)', join q([.]), split m{[.]}mxs, $domain;

  my $c     = Pagesmith::Utils::Curl::Fetcher->new->set_timeout( $THREE_MINUTES );

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
         $type   ||= q(===);
      $c->remove($req);

      push @results, {
        'error'       => $rc ne '200' || $dc ne '200' || !exists $expected{$co} || $type ne $expected{$co} || !exists $valid_response_codes{$rc}{$dc} ?
                         'X' : q(-),
        'error_http'  => $rc ne '200' ? 'HTTP' : q(-),
        'error_das'   => $dc ne '200' ? 'DAS'  : q(-),
        'error_resp'  => exists $expected{$co} ? ( $type eq $expected{$co}||q(-) ? q(-) : q(resp) ) : q(req),
        'error_code'  => exists $valid_response_codes{$rc}{$dc} ? q(-) : q(mismatch),
        'http_code'   => $rc,
        'das_code'    => $dc,
        'command'     => $co,
        'length'      => length $bdy,
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

sub run {
  my $self = shift;

  my $domain = $self->r->headers_in->{'Host'}||'das.sanger.ac.uk';
  ## no critic (LongChainsOfMethodCalls)
  my $start = time;
  my @res = $self->fetch_results( $domain, $self->get_sources( $domain ) );

  return $self->html->wrap( 'DAS status',
    sprintf '<p>Time to retrieve all URLS: %0.3f seconds</p>%s',
      time - $start,
    $self->table
      ->make_sortable
      ->add_class( 'before' )
      ->set_pagination( [qw(10 25 50 all)], '25' )
      ->set_export( [qw(csv xls)] )
      ->set_colfilter
      ->add_columns(
        { 'key' => 'duration',   'caption' => 'Duration', 'format' => 'f3' },
        { 'key' => 'error',      'caption' => 'Error',      'align' => 'c', },
        { 'key' => 'error_http', 'caption' => 'HTTP error', 'align' => 'c', },
        { 'key' => 'error_das', 'caption'  => 'DAS error',  'align' => 'c', },
        { 'key' => 'error_resp', 'caption' => 'Req error',  'align' => 'c', },
        { 'key' => 'error_code', 'caption' => 'Mismatch',   'align' => 'c', },
        { 'key' => 'http_code', 'caption' => 'HTTP code',   'align' => 'c' },
        { 'key' => 'das_code',  'caption' => 'DAS code',    'align' => 'c' },
        { 'key' => 'source',    'caption' => 'Source', },
        { 'key' => 'command',    'caption' => 'Command', },
        { 'key' => 'resp_type', 'caption' => 'Response type', },
        { 'key' => 'length',    'caption' => 'Length', 'format' => 't' },
        { 'key' => 'servers',   'caption' => 'Servers', },
      )->add_data( @res )
      ->set_current_row_class([
       [ 'fatal', 'exact', 'error_http', 'HTTP', ],
       [ 'fatal', 'exact', 'error_das',  'DAS.',  ],
       [ 'fatal', 'exact', 'error_resp', 'REQ.', ],
       [ 'warn',  'exact', 'error_code', 'code', ],
       [ 'warn',  'exact', 'error_resp', 'resp', ],
       [ q() ],
      ])->render,
  )->ok;
  ## use critc
}

1;
