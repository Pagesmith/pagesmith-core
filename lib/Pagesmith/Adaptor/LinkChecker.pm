package Pagesmith::Adaptor::LinkChecker;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
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

## Adaptor for comments database
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

use base qw(Pagesmith::BaseAdaptor);
use Carp qw(cluck);
use Const::Fast qw(const);

const my $MAX_SIZE   => 1<<30;
const my $PROTO_SIZE => 10;

use English qw(-no_match_vars $PROGRAM_NAME);
use Pagesmith::Object::Generic;
use URI;

my $protocols = {};
my $sites     = {};

sub connection_pars {
  return 'link_check';
}

sub get_local_sites {
  my $self = shift;
  return $self->all_hash( 'select site_id, domain, pagesmith from site where local="yes"' );
}
sub add_status {
  my( $self, $status, $title, $description, $flag ) = @_;
  return $self->query( 'insert into status (status, title, description, flag) values (?,?,?)', $status, $title, $description, $flag||q() );
}

sub change_stage {
  my( $self, $url, $stage ) = @_;
  return $self->query( 'update url set stage = ? where href = ?', $stage, $url );
}

sub get_protocol_id {
  my( $self, $protocol ) = @_;
  return $protocols->{$protocol} ||=
    $self->sv( 'select protocol_id from protocol where code = ?', $protocol) ||
    $self->insert( 'insert into protocol (code) values(?)',
      'protocol', 'protocol_id', $protocol );
}

sub get_site_id {
  my( $self, $site ) = @_;
  $site||=q(-);
  return $sites->{$site} ||=
    $self->sv( 'select site_id from site where domain = ?', $site) ||
    $self->insert( 'insert into site (domain) values(?)',
      'site', 'site_id', $site );
}

sub queue_url {
  my( $self, $url  ) = @_;

  my $url_id = $self->sv( 'select url_id from url where href = ?', $url );
  unless( $url_id ) {
    my $u = URI->new($url);
    my $protocol = $u->scheme;
    my $domain   = $u->can('host') ? $u->host||q(-) : q(-);
    my $protocol_id = $self->get_protocol_id( $protocol );
    my $site_id     = $self->get_site_id(     $domain   );
    $url_id = $self->query(
      'insert ignore into url (href, protocol_id, site_id, created_at) values (?,?,?,?)',
      $url, $protocol_id, $site_id, $self->now );
  }
  return $url_id;
}


sub update_url {
  my( $self, $details ) = @_;
  $self->dumper( $details ) if $details->{'length'} > $MAX_SIZE;
  $self->query( 'update url set updated_at = from_unixtime(?), status = ?, duration = ?, size = ? where href = ?',
    int $details->{'end'}, $details->{'code'}, $details->{'time'}, $details->{'length'},
    $details->{'href'} );
  return;
}

sub remove_links {
  my( $self, $href) = @_;
  return $self->query( 'delete url_url from url_url, url where url.url_id = url_url.url_id and url.href = ?',
    $href );
}

## no critic (ImplicitNewlines)
sub add_link {
  my( $self, $href, $link ) = @_;
  return $self->query( 'insert ignore into url_url (url_id,link_id)
    select h.url_id, l.url_id from url as h, url as l where h.href=? and l.href = ?',
    $href, $link );
}

sub get_site_info {
  my( $self, $site_id ) = @_;
  return $self->row_hash( 'select * from site where site_id = ?', $site_id );
}

sub get_all_statuses {
  my $self = shift;
  return $self->all_hash( 'select * from status' );
}

sub get_status_info {
  my( $self, $status ) = @_;
  return $self->row_hash( 'select * from status where status = ?', $status );
}

sub get_site_summary {
  my( $self, $site_id ) = @_;
  return $self->all_hash( '
    select u.status,
           st.title,
           u.stage,
           sum(if(p.code = "http",1,0)) as http,
           sum(if(p.code = "https",1,0)) as https,
           sum(if(p.code = "http" or p.code = "https",0,1)) as other,
           count(*) as total
      from (url u left join status st on st.status = u.status), protocol p
     where p.protocol_id = u.protocol_id and u.site_id = ?
     group by stage, status',
    $site_id,
  );
}

sub get_ref_summary {
  my( $self, $site_id ) = @_;
  return $self->all_hash( '
    select u.status,
           st.title,
           u.stage,
           sum(if(p.code = "http",1,0)) as http,
           sum(if(p.code = "https",1,0)) as https,
           sum(if(p.code = "http" or p.code = "https",0,1)) as other,
           count(*) as total,
           count(distinct u.url_id) as different
      from url as r, url_url as l, url u left join status st on st.status = u.status, protocol p
     where p.protocol_id = u.protocol_id and r.site_id = ? and
           l.link_id = u.url_id and r.url_id = l.url_id and u.site_id != r.site_id
     group by stage, status',
    $site_id,
  );
}

sub get_external_sites_stats {
  my $self = shift;
  return $self->get_local_sites_stats(1);
}

sub get_local_sites_stats {
  my( $self, $flag ) = @_;
  return $self->all_hash( '
    select if(st.local="yes",st.site_id,"")           as ID,
           if(st.local="yes",st.domain,"External sites") as domain,
           count(*) as total_pages,
           sum( if(stage = "queued",    1,0) ) as total_queued,
           sum( if(stage = "fetched",   1,0) ) as total_fetched,
           sum( if(stage = "fetching",  1,0) ) as total_fetching,
           sum( if(stage = "requeued",  1,0) ) as total_requeued,
           sum( if(stage = "skipped",   1,0) ) as total_skipped,
           sum( if(stage = "invalid",   1,0) ) as total_invalid,
           sum( if(stage in ("invalid","skipped"), 0,1) ) as total_requested,
           sum( if(stage = "fetched" and status between   1 and  99, 1, 0 ) ) as curl_errors,
           sum( if(stage = "fetched" and status between 100 and 199, 1, 0 ) ) as http_info,
           sum( if(stage = "fetched" and status between 200 and 299, 1, 0 ) ) as http_success,
           sum( if(stage = "fetched" and status between 300 and 399, 1, 0 ) ) as http_redirect,
           sum( if(stage = "fetched" and status between 400 and 499, 1, 0 ) ) as http_resource,
           sum( if(stage = "fetched" and status between 500 and 599, 1, 0 ) ) as http_server
      from site st, url as u
     where st.site_id = u.site_id and local = ?
     group by ID
     order by domain',
    defined $flag ? 'no' : 'yes',
  );
}

sub get_site_status {
  my( $self, $site_id, $status, $stage ) = @_;
  return $self->all_hash( '
    select u.href as page, r.href as ref
      from url as u left join
           url_url as l on u.url_id = l.link_id left join
           url as r     on l.url_id = r.url_id
     where u.site_id = ? and u.status = ? and u.stage = ?',
     $site_id, $status, $stage,
  );
}

sub get_site_refstatus {
  my( $self, $site_id, $status, $stage ) = @_;
  return $self->all_hash( '
    select u.href as page, r.href as ref
      from url as u, url_url as l, url as r
     where r.site_id = ? and u.status = ? and u.stage = ? and u.url_id = l.link_id and l.url_id = r.url_id and r.site_id!=u.site_id',
     $site_id, $status, $stage,
  );
}
## use critic
1;
