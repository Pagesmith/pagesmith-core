package Pagesmith::Action::Das;

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

use base qw(Pagesmith::Action);
use List::MoreUtils qw(any none);

use Apache2::Const qw(HTTP_BAD_REQUEST);

use Const::Fast qw(const);

const my $BAD_COMMAND     => 400;
const my $BAD_SOURCE      => 401;
const my $NOT_IMPLEMENTED => 501;
const my $VALID_REQUEST   => 200;

const my $TIMEOUT_FETCH   => 240;
const my $TIMEOUT_SOURCES => 240;

const my $FRAC_SOURCES_DOCS_REQUIRED => 0.8; ## Don't write cache unless 80% of sources have sources docs!
const my $MIN_FRAC_OF_OLD_DOCS       => 0.8; ## Don't write cache if no of sources < 80% of current list!

const my %VALID_COMMANDS  => map { $_ => 1 } qw(
  sources dsn
  entry_points sequence types features stylesheet structure dna link
);

use Pagesmith::Utils::Curl::Fetcher;
use Pagesmith::ConfigHash qw(template_name);

sub das_config {
  my $self = shift;
  return $self->{'sources_config'} || $self->fetch_config;
}

sub das_error_message {
  my( $self, $status, $das_status, $subject, $body ) = @_;
  $self->xml;
  $self->r->err_headers_out->set( 'X-Das-Status', $das_status );
  $self->r->err_headers_out->set( 'access-control-allow-credentials', 'true' );
  $self->r->err_headers_out->set( 'access-control-allow-origin', q(*) );
  $self->r->err_headers_out->set( 'access-control-expose-headers', 'X-DAS-Version, X-DAS-Server, X-DAS-Status, X-DAS-Capabilities' );
  $self->r->err_headers_out->set( 'x-das-capabilities', 'sources/1.0; dsn/1.0' );
  $self->r->err_headers_out->set( 'x-das-server', 'PagesmithDasProxy/1' );
  $self->r->err_headers_out->set( 'x-das-version', 'DAS/1.6E' );
  $self->r->status( $status );
  $self->r->status_line( 'DAS ERROR' );
  $self->r->err_headers_out->set( 'Status'   => "$status DAS_ERROR" );
  my $str = sprintf qq(<?xml version="1.0" encoding="UTF-8"?>\n<error>\n<![CDATA[\n\n%s\n\n%s\n\n]]>\n</error>),
    $subject,
    $body;
  $self->r->err_headers_out->add( 'Content-Length', length $str );
  $self->print( $str );
  return $status;
}

sub filtered_sources {
  my $self = shift;
  my @sources       = values %{$self->fetch_config||{}};
  my @client_realms = split m{,\s+}mxs, $self->r->headers_in->get('ClientRealm')||q();

  ## If client isn't in any realm then we return only those with no realms defined...
  my @s = grep { ! @{$_->{'realms'}||[]} } @sources;

  return @s unless @client_realms;

  ## If the client has realms we return those with no realms defined OR those
  ## whose realm list overlaps with the client_realms list!
  my @q = grep {   @{$_->{'realms'}||[]} } @sources;

  my %client_realms = map { $_=>1 } @client_realms;
  push @s,
    grep { any { exists $client_realms{$_} } @{$_->{'realms'}} }
    @q;
  return @s;
}

sub fetch_config {
  my( $self, $flush ) = @_;
  $flush ||= 0;
  if( $flush || ! exists $self->{'sources_config'} ) {
    my $pch = $self->cache( 'tmpdata', 'config|das-sources' );
    my $details = $pch->get;
    if( $flush || ! $details ) {
      my $conf = $self->config('das')->load(1)->get;
      my $n_old_docs     = $details ? keys %{$details} : 0;
      $details = $self->retrieve( $conf );
      my $n_sources_docs = grep { $_->{'sources_docs'} } values %{$details};
      my $n_docs         = values %{$details};
      $pch->set( $details ) if $self->param('force')
        || $n_sources_docs > $n_docs     * $FRAC_SOURCES_DOCS_REQUIRED
        || $n_docs         > $n_old_docs * $MIN_FRAC_OF_OLD_DOCS
        ;
    }
    $self->{'sources_config'} = $details;
  }
  return $self->{'sources_config'};
}

sub sources_markup {
  my( $self, @sources ) = @_;
  $self->r->headers_out->set( 'X-Das-Capabilities', 'sources/1.0; dsn/1.0' );
  $self->r->headers_out->set( 'X-Das-Status',       $VALID_REQUEST );
  my $markup = sprintf
    qq(<?xml version="1.0" encoding="UTF-8" ?>\n<?xml-stylesheet type="text/xsl" href="/core/css/das.xsl"?>\n<SOURCES>%s</SOURCES>),
    join q(),
    map { $_->{'sources_doc'} }
    @sources;
  return $self->xml->set_length( length $markup )->print( $markup )->ok;
}

sub run {
  my $self = shift;
  my $source  = $self->next_path_info || q();

  my $command = $self->next_path_info || q();
  return $self->redirect( '/das/sources' ) unless $source;
  ## Now we get backend for source ...
  my $config = $self->fetch_config;

  return $self->das_error_message(
    $self->bad_request,
    $BAD_SOURCE,
    'Invalid source',
    'We do not recognise the source requested',
   ) unless exists $config->{$source};

  my $details = $config->{$source};

  unless( $command ) {
    return $self->sources_markup( $details ) if $details->{'sources_doc'};
    return $self->das_error_message( $self->server_error, $NOT_IMPLEMENTED, 'Misconfigured source', 'The source does not have a sources doc' );
  }

  return $self->das_error_message( $self->bad_request, $BAD_COMMAND, 'Unrecognised command', 'You must specify a valid command'  ) unless exists $VALID_COMMANDS{ $command };
  ## We may want to extend this as we could check capabilities as well!!!?! yarg!

  ## Now we map backend server and proxy command to it!
  ## Check security!!!
  my @realms = @{$details->{'realms'}};

  if( @realms ) {
    my @client_realms = split m{,\s+}mxs, $self->r->headers_in->get('ClientRealm')||q();
    my %client_realms = map { ($_=>1) } @client_realms;
    return $self->das_error_message( $self->bad_request, $BAD_SOURCE, 'Invalid source', 'This sources is restricted' )
      if none { exists $client_realms{$_} } @realms;
  }
  ## OK - finally do the fetch....
  $self->xml;
  my $c = Pagesmith::Utils::Curl::Fetcher->new->set_timeout( $TIMEOUT_FETCH );
  $c->set_resp_class( 'Pagesmith::Utils::Curl::Response::Das' );
  my $req = $c->new_request( sprintf q(http://%s/%s/%s?%s), $details->{'backend'}, $source, $command, $self->args )->init;
     $req->response->set_r(        $self->r        );
     $req->response->set_das_url(  $self->base_url.'/das' );
  my $st;

  while( $c->has_active ) {
    next if $c->active_transfers == $c->active_handles;
    while( my $r = $c->next_request ) {
      $st = $r->response->{'code'};
      $c->remove($r);
    }
  }
  ## We will look to use CURL here - but hack the handler to parse in chunks!!!
  return $self->ok if $st eq '200';
  return $st;
}

sub retrieve {
#@params ($self) (hashref $conf - server configuration hash)
#@return hashref{} details of source
## Uses curl to fetch sources/dsn commands from all configured backend servers
## and stores the details in a hashref.
##
## Each entry in the hashref is itself a hash with keys
##
## * sources_doc - re-written sources doc fragment
## * dsn_doc     - re-written dsn doc fragment
## * backend     - name of machine/port to send request back to
## * realms      - realms which access has to come from!
##
## Uses curl and Pagesmith::Utils::Curl::Response::Das::Sources/DSN to parallelize
## fetchs to minimise response time.
##
## Results are merged in order - sources with sources command, sources with only dsn
## command, and within each group in order of the backend servers supplied.
## Only the first source for a given "name" is returned.


  my( $self, $conf ) = @_;

  my $c = Pagesmith::Utils::Curl::Fetcher->new->set_timeout( $TIMEOUT_SOURCES );
  my @hosts = @{$conf->{'hosts'}||[]};

  my @my_hosts = map { "http://$_" } @{$conf->{'my_hosts'}||[]};
  my $my_hosts = { map { ( $_ => 1 ) } @my_hosts };

  foreach my $host ( @hosts ) {
    my $k = lc "http://$host";
    $my_hosts->{ $k }++;
    $c->set_resp_class( 'Pagesmith::Utils::Curl::Response::Das::Sources' );
    $c->new_request( "http://$host/sources" )->init;
    $c->set_resp_class( 'Pagesmith::Utils::Curl::Response::Das::DSN' );
    $c->new_request( "http://$host/dsn"     )->init;
  }
  my %values;
  while( $c->has_active ) {
    next if $c->active_transfers == $c->active_handles;
    while( my $req = $c->next_request ) {
      my( $domain, $type ) = $req->url =~ m{\Ahttp://(.*?)/(dsn|sources)\Z}mxsg;
      $c->remove( $req );
      $values{ $domain }{$type} = $req->response->{'_sources_'};
    }
  }
  my $restrictions = $conf->{'realms'}||{};
  my $sources;
  foreach my $host ( @hosts ) {
    foreach my $k ( sort keys %{$values{$host}{'sources'}||{}} ) {
      next if exists $sources->{$k}; ## #already seen!
      $sources->{$k} = $self->modify( {
        'sources_doc' => $values{ $host }{ 'sources' }{$k},
        'dsn_doc'     => $values{ $host }{ 'dsn'     }{$k}||q(),
        'backend'     => $host,
      }, $my_hosts, \@my_hosts);
      $sources->{$k}{'realms'} = $restrictions->{$k}||[];
    }
  }
  foreach my $host ( @hosts ) {
    foreach my $k ( sort keys %{$values{$host}{'dsn'}||{}} ) {
      next if exists $sources->{$k}; ## #already seen!
      $sources->{$k} = $self->modify( {
        'sources_doc' => q(),
        'dsn_doc'     => $values{ $host }{ 'dsn'     }{$k}||q(),
        'backend'     => $host,
      }, $my_hosts, \@my_hosts );
      $sources->{$k}{'realms'} = $restrictions->{$k}||[];
    }
  }
  ## Now we have to re-write the sources and dsn commands...
  #$self->dumper( $sources );
  return $sources;
}

sub modify {
## Rewrites sources/dsn documents - basically replacing URLs...
  my( $self, $source_conf, $my_hosts, $front_end_hosts ) = @_;
  (my $regexp  = qq(uri="http://$source_conf->{'backend'})) =~ s{[.]}{[.]}mxsg;
  my $replace     = 'uri="'.$self->base_url.'/das';
  my $replace_doc = 'doc_href="'.$self->base_url.'/das';
  $source_conf->{'sources_doc'} =~ s{/+das/+}{/das/}mxsg;
  $source_conf->{'dsn_doc'}     =~ s{/+das/+}{/das/}mxsg;

  $source_conf->{'sources_doc'} =~ s{$regexp}{$replace}mxsig;
  foreach my $fh ( @{$front_end_hosts} ) {
    ( my $r = qq(uri="$fh) ) =~ s{[.]}{[.]}mxsg;
    $source_conf->{'sources_doc'} =~ s{$r}{$replace}mixsg;
    ( my $t = qq(doc_href="$fh) ) =~ s{[.]}{[.]}mxsg;
    $source_conf->{'sources_doc'} =~ s{$t}{$replace_doc}mixsg;
  }
  $source_conf->{'dsn_doc'}     =~ s{(<MAPMASTER>)\s*(.*?)(/[^/<\s]+/?\s*</MAPMASTER>)}{ exists $my_hosts->{lc $2} ? $1.$self->base_url.'/das'.$3 : $1.$2.$3 }mxseg;
  return $source_conf;
}

1;
