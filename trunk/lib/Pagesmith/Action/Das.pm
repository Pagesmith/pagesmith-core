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

use Const::Fast qw(const);

const my $TIMEOUT_FETCH   => 600;
const my $TIMEOUT_SOURCES => 120;
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
      $details = $self->retrieve( $conf );
      $pch->set( $details );
    }
    $self->{'sources_config'} = $details;
  }
  return $self->{'sources_config'};
}

sub run_xsl {
  my $self = shift;
  ## Move these out and slurp!
  ## no critic (ImplicitNewlines InterpolationOfMetachars)
  return $self->content_type('text/xsl')->print(q(<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html" indent="yes"/>
<xsl:template match="/">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <style type="text/css">
    html,body {font-family:helvetica,arial,sans-serif;font-size:0.8em}
    h2, table    { width: 95%; margin: 0 auto }
    h2 { border:1px solid white }
    h2 span { font-size: 1.5em; padding: 2px 0.5em }
    h2, thead    {background:#ddd}
    thead th {margin:0;padding:2px}
    .tr1     {background:#eee}
    .tr2     {background:#ffb}
    tr{vertical-align:top}
  </style>
  <title>Features for <xsl:value-of select="/DASGFF/GFF/@href"/></title>
</head>
<body>
  <h2><span>Features for <xsl:value-of select="/DASGFF/GFF/@href"/></span></h2>
  <table class="z" id="data">
  <thead>
    <tr>
      <th>Label</th>
      <th>Segment</th>
      <th>Start</th>
      <th>End</th>
      <th>Orientation</th>
      <th>Type</th>
      <th>Notes</th>
      <th>Link</th>
    </tr>
  </thead>
  <tbody>
    <xsl:apply-templates select="/DASGFF/GFF/SEGMENT"/>
  </tbody>
  </table>
</body>
</html>
</xsl:template>

<xsl:template match="SEGMENT">
  <xsl:for-each select="FEATURE">
    <xsl:sort select="@id"/>
    <tr>
      <td><xsl:value-of select="@id"/></td>
      <td><xsl:value-of select="../@id"/></td>
      <td><xsl:value-of select="START"/></td>
      <td><xsl:value-of select="END"/></td>
      <td><xsl:value-of select="ORIENTATION"/></td>
      <td><xsl:value-of select="TYPE"/></td>
      <td><xsl:apply-templates select="NOTE"/></td>
      <td><xsl:if test="LINK"><xsl:apply-templates select="LINK"/></xsl:if></td>
    </tr>
  </xsl:for-each>
</xsl:template>

<xsl:template match="NOTE">
  <xsl:value-of select="."/>
  <xsl:if test="position()!=last()"><br/></xsl:if>
</xsl:template>

<xsl:template match="LINK">
  [<a><xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute><xsl:value-of select="."/></a>]
</xsl:template>

</xsl:stylesheet>
) )->ok;
  ## use critic
}
sub run {
  my $self = shift;
  my $source  = $self->next_path_info || q();

  return $self->run_xsl if $source eq 'das.xsl';

  my $command = $self->next_path_info || q();
  return $self->redirect( '/das/sources' ) unless $source;
  ## Now we get backend for source ...
  my $config = $self->fetch_config;

  return $self->wrap( 'Invalid source', '<p>Do not recognise source</p>' )->ok unless exists $config->{$source};

  my $details = $config->{$source};

  unless( $command ) {
    return $self->wrap( 'Misconfigured sources', '<p>No sources information</p>' )->ok unless $details->{'sources_doc'};
    return $self->xml->print( '<SOURCES>'.$details->{'sources_doc'}.'</SOURCES>' )->ok;
  }

  return $self->wrap( 'Invalid command', '<p>You must specify a valid command</p>'  )->ok unless exists $VALID_COMMANDS{ $command };
  ## We may want to extend this as we could check capabilities as well!!!?! yarg!

  ## Now we map backend server and proxy command to it!
  ## Check security!!!
  my @realms = @{$details->{'realms'}};

  if( @realms ) {
    my @client_realms = split m{,\s+}mxs, $self->r->headers_in->get('ClientRealm')||q();
    my %client_realms = map { ($_=>1) } @client_realms;
    return $self->wrap( 'Invalid source', '<p>This sources is restricted</p>' )->ok
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
  return $self->ok if $st ne '200';
  return $st;
}

sub retrieve {
  my( $self, $conf ) = @_;

  my $c = Pagesmith::Utils::Curl::Fetcher->new->set_timeout( $TIMEOUT_SOURCES );
  my @hosts = @{$conf->{'hosts'}||[]};

  my $my_hosts = { map { ("http://$_" => 1) } @{$conf->{'my_hosts'}||[]} };

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
      }, $my_hosts );
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
      }, $my_hosts );
      $sources->{$k}{'realms'} = $restrictions->{$k}||[];
    }
  }
  ## Now we have to re-write the sources and dsn commands...
  #$self->dumper( $sources );
  return $sources;
}

sub modify {
  my( $self, $source_conf, $my_hosts ) = @_;
  (my $regexp  = qq(uri="http://$source_conf->{'backend'})) =~ s{[.]}{[.]}mxsg;
  my $replace = 'uri="'.$self->base_url.'/das';
  $source_conf->{'sources_doc'} =~ s{/+das/+}{/das/}mxsg;
  $source_conf->{'dsn_doc'}     =~ s{/+das/+}{/das/}mxsg;

  $source_conf->{'sources_doc'} =~ s{$regexp}{$replace}mxsig;
  $source_conf->{'sources_doc'} =~ s{uri="http://das[.]sanger[.]ac[.]uk/das}{$replace}mixsg;
  $source_conf->{'dsn_doc'}     =~ s{(<MAPMASTER>)\s*(.*?)(/[^/<\s]+/?\s*</MAPMASTER>)}{ exists $my_hosts->{lc $2} ? $1.$self->base_url.'/das'.$3 : $1.$2.$3 }mxseg;
  return $source_conf;
}

1;
