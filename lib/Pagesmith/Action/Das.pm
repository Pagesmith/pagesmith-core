package Pagesmith::Action::Das;

## Intelligent, load balancing proxy to merge multiple internal das servers together behind a single front end URL
##
## Handles
##  * nicely formatting server errors!
##  * merging DSN/Sources list and re-writing response to supply proxy URLs where appropriate through out
##  * re-writing DAS requests (URLs)
##  * making multiple attempts to request sources from the backend servers
##  *
##  *
##
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

use Const::Fast     qw(const);

## Das response codes...
const my $PROXY_NAME      => 'PagesmithDas::Proxy/1';
const my $BAD_COMMAND     => 400;
const my $BAD_SOURCE      => 401;
const my $NOT_IMPLEMENTED => 501;
const my $VALID_REQUEST   => 200;

## Timeouts etc...
const my $TIMEOUT_FETCH   => 240; ## 4 minutes..
const my $TIMEOUT_CONN    => 3;   ## 3 seconds..
const my $TIMEOUT_SOURCES => 240; ## 4 minutes..

const my $MAX_TRIES       => 3;   ## Tries up to 3 times to get response from backends before giving up!

## Following are used to try and stop a re-write of a badgered config...

const my $FRAC_SOURCES_DOCS_REQUIRED => 0.8; ## Don't write cache unless 80% of sources have sources docs!
const my $MIN_FRAC_OF_OLD_DOCS       => 0.8; ## Don't write cache if no of sources < 80% of current list!

## If you wish to add any more das commands to be
## proxied back then you need to add them to this
## list...
## Note sources command is handled specicially!

const my %VALID_COMMANDS  => map { $_ => 1 } qw(
  entry_points sequence types features stylesheet structure dna link
);

use List::MoreUtils qw(any none);
use Pagesmith::Utils::Curl::Fetcher;

sub das_error_message {
#@params (self) (status int - HTTP status) (das_status int - DAS status) (message string+ DAS error message...)
#@return (int) HTTP error code!
## Renders a DAS XML document with appropriate headers... and the error message wrapped in a CDATA block...
  my( $self, $status, $das_status, @message ) = @_;

  my $str = sprintf qq(<?xml version="1.0" encoding="UTF-8"?>\n<error>\n<![CDATA[\n\n%s\n\n]]>\n</error>),
    join qq(\n\n), @message;

  $self->xml->do_not_throw_extra_error;

  $self->r->status(               $status );
  $self->r->status_line(          'DAS ERROR' );

  $self->r->err_headers_out->set( 'X-DAS-Status', $das_status );
  $self->r->err_headers_out->set( 'Access-Control-Allow-Credentials', 'true' );
  $self->r->err_headers_out->set( 'Access-Control-Allow-Origin', q(*) );
  $self->r->err_headers_out->set( 'Access-Control-Expose-Headers', 'X-DAS-Version, X-DAS-Server, X-DAS-Status, X-DAS-Capabilities' );
  $self->r->err_headers_out->set( 'X-DAS-Capabilities', 'sources/1.0; dsn/1.0' );
  $self->r->err_headers_out->set( 'X-DAS-Server', $PROXY_NAME );
  $self->r->err_headers_out->set( 'X-DAS-Version', 'DAS/1.6E' );
  $self->r->err_headers_out->set( 'Status'   => "$status DAS_ERROR" );
  $self->r->err_headers_out->set( 'Content-Length', length $str );

  $self->print( $str );

  return $status;
}

sub filtered_sources {
#@param (self)
#@return (hashref+ details)
## Returns an array of sources - filtered by the realm the user is in

  my $self = shift;

  my $conf = $self->fetch_config(1)||{}; ## Get version of config which contains the sources info!

  my @sources       = map { $conf->{$_} } sort { lc $a cmp lc $b } keys %{$conf};

  my @client_realms = split m{,\s+}mxs, $self->r->headers_in->get('ClientRealm')||q();

  ## If client isn't in any realm then we return only those with no realms defined...
  my @s = grep { ! @{$_->{'realms'}||[]} } @sources;

  ## No realms.. so we just show return the public list!
  return @s unless @client_realms;

  ## If the client has realms we push those whose realm list overlaps with the client_realms list!

  my @q = grep {   @{$_->{'realms'}||[]} } @sources;
  my %client_realms = map { $_=>1 } @client_realms;

  push @s, grep { any { exists $client_realms{$_} } @{$_->{'realms'}} } @q;

  return @s;
}

sub fetch_config {
#@params (self) (full bool - Return full doc - including DSN/sources) (flush bool - ignore cache)
#@return (hashref) config data structure
  my( $self, $full, $flush ) = @_;
  my $config_type = $full ? 'full' : 'partial';
  $flush ||= 0;
  ## If flush then we will always fetch the object..
  ## o/w only fetch if it doesn't exist!
  if( $flush || ! exists $self->{"sources_config_$config_type"} ) {
    ## We need to fetch, and parse the data to generate data structure!
    my $pch = $self->cache( 'tmpdata', "config|das-sources-$config_type" );
    my $details = $pch->get;
    if( $flush || ! $details ) {
      my $pch_full    = $config_type eq 'full'    ? $pch : $self->cache( 'tmpdata', 'config|das-sources-full'    );
      my $pch_partial = $config_type eq 'partial' ? $pch : $self->cache( 'tmpdata', 'config|das-sources-partial' );
      my $conf           = $self->config('das')->load(1)->get;
      my $n_old_docs     = $details ? keys %{$details} : 0;
      $details = $self->retrieve( $conf );
      my @s = values %{$details};
      my $n_sources_docs = grep { $_->{'sources_doc'} } @s;
      my $n_docs         = @s;
      my $partial = { map {$_ => {
        'backend' => $details->{$_}{'backend'},
        'realms'  => $details->{$_}{'realms'},
      } } keys %{$details} };
      if( $self->param('force')
        || $n_sources_docs > $n_docs     * $FRAC_SOURCES_DOCS_REQUIRED
        || $n_docs         > $n_old_docs * $MIN_FRAC_OF_OLD_DOCS
      ) {
        $pch_full->set( $details );
        $pch_partial->set( $partial );
      }
      $self->{'sources_config-full'   } = $details;
      $self->{'sources_config-partial'} = $partial;
    } else {
      $self->{"sources_config-$config_type"} = $details;
    }
  }
  return $self->{"sources_config-$config_type"};
}

sub sources_markup {
#@params (self) (sources hashref+ - full details of sources)
#@return (int) status OK!
## Generates an appropriate sources document!
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

## no critic (ExcessComplexity)
sub run {
  my $self = shift;
  my $source  = $self->next_path_info || q();

  my $command = $self->next_path_info || 'sources';
  return $self->redirect( '/das/sources' ) unless $source;

  ## Now we get backend for source ...
  my $config = $self->fetch_config( $command eq 'sources' );

  return $self->das_error_message(
    $self->bad_request,
    $BAD_SOURCE,
    'Invalid source',
    'We do not recognise the source requested',
   ) unless exists $config->{$source};

  my $details = $config->{$source};

  if( $command eq 'sources' ) {
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
  ## no critic (LongChainsOfMethodCalls)
  my $c = Pagesmith::Utils::Curl::Fetcher->new
          ->set_timeout( $TIMEOUT_CONN  )
          ->set_timeout( $TIMEOUT_FETCH )
          ->set_resp_class( 'Pagesmith::Utils::Curl::Response::Das' );
  ## use critic
  my @urls = map { sprintf q(http://%s/%s/%s?%s), $_, $source, $command, $self->args } @{$details->{'backend'}};

  my $req_url = splice @urls, rand @urls, 1;
  my $req_count = 1;
  my $req = $c->new_request_obj( $req_url, $details->{'backend'}, $source, $command, $self->args );
     $req->response->set_r(        $self->r        );
     $req->response->set_das_url(  $self->base_url.'/das' );
     $c->add( $req );
  my $st;
  while( $c->has_active ) {
    next if $c->active_transfers == $c->active_handles;

    while( my $r = $c->next_request ) {
      $st = $r->response->{'code'};
      $c->remove($r);
      if( $r->response->{'success'} ) {
        $st = $r->response->{'code'};
      } elsif( @urls && $req_count <= $MAX_TRIES ) {
        $req_url = splice @urls, rand @urls, 1;
        $self->r->err_headers_out->add( 'X-DAS-RealURL'   => $r->response->url );
        $req = $c->new_request_obj( $req_url, $details->{'backend'}, $source, $command, $self->args );
        $req->response->set_r(        $self->r        );
        $req->response->set_das_url(  $self->base_url.'/das' );
        $c->add( $req );
        $req_count++;
      } else {
        ## We need to know send the error page... assume we send the last one!
        $st = $r->response->{'code'};
        my $headers = $r->response->headers_hash;
        $headers->{'X-DAS-Version'}                    ||= ['DAS/1.6E'];
        $headers->{'Access-Control-Allow-Credentials'} ||= [ 'true' ];
        $headers->{'Access-Control-Allow-Origin'}        = [ q(*)];
        $headers->{'Access-Control-Expose-Headers'}    ||= ['X-DAS-Version, X-DAS-Server, X-DAS-Status, X-DAS-Capabilities'];
        $headers->{'X-DAS-Capabilities'}               ||= ['sources/1.0; dsn/1.0'];
        push @{$headers->{'X-DAS-Server'}}, $PROXY_NAME;

        $self->r->status( $st );
        $self->r->status_line( 'DAS ERROR' );
        $self->r->err_headers_out->set( 'Status'   => "$st DAS_ERROR" );

        foreach my $hk ( keys %{$headers} ) {
          $self->r->err_headers_out->add( $hk, $_ ) foreach @{$headers->{$hk}};
        }
        $self->print( $r->response->body );
        $self->do_not_throw_extra_error;
      }
    }
  }
  ## We will look to use CURL here - but hack the handler to parse in chunks!!!
  return $self->ok if $st eq '200';
  return $st;
}

sub retrieve {
#@params (self) (conf hashref - server configuration hash)
#@return (hashref{}) details of source
##
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

  my @order = split m{\s+}mxs, $conf->{'order'};
  my %hosts = %{$conf->{'hosts'}||{}};
     @order = sort keys %hosts unless @order;

  my @my_hosts = map { "http://$_" } @{$conf->{'my_hosts'}||[]};
  my $my_hosts = { map { ( $_ => 1 ) } @my_hosts };

  foreach my $block ( @order ) {
    foreach my $host ( @{$hosts{$block}||[]} ) {
      my $k = lc "http://$host";
      $my_hosts->{ $k }++;
      $c->set_resp_class( 'Pagesmith::Utils::Curl::Response::Das::Sources' );
      $c->new_request( "http://$host/sources" )->init;
      $c->set_resp_class( 'Pagesmith::Utils::Curl::Response::Das::DSN' );
      $c->new_request( "http://$host/dsn"     )->init;
    }
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
  my $seen = {};
  foreach my $type ( qw(sources dsn) ) {
    foreach my $block ( @order ) {
      foreach my $host ( @{$hosts{$block}||[]} ) {
        foreach my $k ( sort keys %{$values{$host}{$type}||{}} ) {
          next if exists $seen->{$k}; ## #already seen!
          if( exists $sources->{$k} ) {
            push @{$sources->{$k}->{'backend'}}, $host;
            next;
          }
          $sources->{$k} = $self->modify( {
            'backend_key' => $block,
            'sources_doc' => $values{ $host }{ 'sources' }{$k}||q(),
            'dsn_doc'     => $values{ $host }{ 'dsn'     }{$k}||q(),
            'backend'     => [$host],
          }, $my_hosts, \@my_hosts);
          $sources->{$k}{'realms'} = $restrictions->{$k}||[];
        }
      }
      $seen->{$_}++ foreach keys %{$sources};
    }
  }

  return $sources;
}
## use critic

sub modify {
## Rewrites sources/dsn documents - basically replacing URLs...
  my( $self, $source_conf, $my_hosts, $front_end_hosts ) = @_;
  my $replace     = 'uri="'.$self->base_url.'/das';
  my $replace_doc = 'doc_href="'.$self->base_url.'/das';
  $source_conf->{'sources_doc'} =~ s{/+das/+}{/das/}mxsg;
  $source_conf->{'dsn_doc'}     =~ s{/+das/+}{/das/}mxsg;

  foreach my $s (@{$source_conf->{'backend'}}) {
    (my $regexp     = qq(uri="(?:http://)?$s)      ) =~ s{[.]}{[.]}mxsg;
    (my $regexp_doc = qq(doc_href="(?:http://)?$s) ) =~ s{[.]}{[.]}mxsg;
    $source_conf->{'sources_doc'} =~ s{$regexp}{$replace}mxsig;
    $source_conf->{'sources_doc'} =~ s{$regexp_doc}{$replace_doc}mxsig;
  }

  foreach my $fh ( @{$front_end_hosts} ) {
    ( my $r = qq(uri="$fh) ) =~ s{[.]}{[.]}mxsg;
    $source_conf->{'sources_doc'} =~ s{$r}{$replace}mixsg;
    ( my $t = qq(doc_href="$fh) ) =~ s{[.]}{[.]}mxsg;
    $source_conf->{'sources_doc'} =~ s{$t}{$replace_doc}mixsg;
  }
  $source_conf->{'dsn_doc'}     =~ s{(<MAPMASTER>)\s*(.*?)(/[^/<\s]+/?\s*</MAPMASTER>)}{ exists $my_hosts->{lc $2} ? $1.$self->base_url.'/das'.$3 : $1.$2.$3 }mxseg;

  ($source_conf->{'maintainer'}) = $source_conf->{'sources_doc'} =~ m{<MAINTAINER\s+email="(.*?)"}mxs ? $1 : q(-);
  return $source_conf;
}

1;
