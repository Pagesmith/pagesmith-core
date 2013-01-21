package Pagesmith::Adaptor::Reference;

## Adaptor to retrieve references from pubmed or the database
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

use base qw(Pagesmith::Adaptor);

use DBI;
use URI::Escape qw(uri_escape_utf8);
use Encode::Unicode;
use HTML::Entities qw(encode_entities decode_entities);
use LWP::Simple qw($ua get);
use Time::HiRes q(time);
use Readonly qw(Readonly);

Readonly my $BATCH_SIZE => 200;

use Pagesmith::ConfigHash qw(get_config);

use Pagesmith::Object::Reference;

sub connection_pars {
  return 'references';
}

sub new {
  my $class             = shift;
  my $self              = $class->SUPER::new( );
  $self->{'_proxy_url'} = get_config( 'ProxyURL' );
  return $self;
}

sub get_entry {
  my( $self, $id ) = @_;
  my ($present) = $self->get_entries( $id );
  return $present->[0] if @{$present};
  return;
}

sub get_entries {
  my ( $self, @entries ) = @_;
  my $time = time;
  my %types = qw(
    pubmed  pubmed  pmid  pubmed  p     pubmed pm pubmed
    pmc     pmc
    d       doi     doi   doi     doid  doi
    sid     sid     id    id
  );

  my @split_ids;
  my $ids       = {};
  foreach (@entries) {
    s{[,;.]\Z}{}mxs; ## Remove trailing list punctuation that may have crept in by mistake
    my ( $type, $id ) =
        m{\APMC(\d+)\Z}mxs  ? ( 'pmc', $1 )
      : m{\ASID_(\d+)\Z}mxs ? ( 'sid', $1 )
      : m{/}mxs             ? ( 'doi', $_ )
      : m{:}mxs             ? split( m{:}mxs, $_, 2 )
      :                      ( 'pmid', $_ );
    $type = exists $types{$type} ? $types{$type} : 'pmid';
    push @split_ids, [$type, $id];
    $ids->{$type}{$id}++;
  }
  my $res = {};
  foreach ( sort keys %{$ids} ) {
    $res->{$_} = $self->get_entries_type( $_, keys %{ $ids->{$_} } );
  }
  my @present;
  my @missing;
  foreach (@split_ids) {
    if ( exists $res->{ $_->[0] }{ $_->[1] } ) {
      push @present, $res->{ $_->[0] }{ $_->[1] };
    } else {
      push @missing, $_;
    }
  }
  return ( \@present, \@missing );
}

sub get_entries_type {
  my ( $self, $type, @ids ) = @_;

  my ( $entries, $to_fetch ) = $self->fetch_from_db( $type, @ids );
  if ( ( $type eq 'pubmed' || $type eq 'doi' ) && @{$to_fetch} ) {
    if( $type eq 'doi' ) {
      @{$to_fetch} = $self->_doi_to_pubmed( @{$to_fetch} );
    }
    while( my @list = splice @{$to_fetch}, 0, $BATCH_SIZE ) {
      my $xml         = $self->fetch_pubmed_xml( @list );
      my $tmp_entries = $self->parse_pubmed_xml($xml);
      foreach ( @{$tmp_entries} ) {
        if( $_->pubmed && exists $entries->{ $_->pubmed } ) {
          $_->set_id( $entries->{ $_->pubmed }->id );
          $self->write_to_db( $_, 'update' );
        } else {
          $self->write_to_db( $_, 'insert' );
        }
        if( exists $entries->{ $_->pubmed } ) {
          $_->set_sid(      $entries->{ $_->pubmed }->sid );       ## Copy the SID
          $_->set_class_id( $entries->{ $_->pubmed }->class_id );  ## Copy the Class ID
          $_->set_url(      $entries->{ $_->pubmed }->url );       ## Copy the URL - these ones are un-retrievable from pubmed!
          $entries->{ $_->pubmed } = $_;
        }
      }
    }
  }
  return $entries;
}

sub write_to_db {
  my ( $self, $entry, $flag ) = @_;
  unless( $flag ) {
    if( $entry->id ) {
      $flag = 'update';
    } else {
      my $tid   = $self->sv( 'select id from entry where pubmed=?', $entry->pubmed );
      $flag       = $tid ? 'update' : 'insert';
      $entry->set_id( $tid ) if $tid;
    }
  }
  my ($now) = $self->now;
  (my $search = join q( ), grep { $_ }
    $entry->pubmed, $entry->doi, $entry->pmc, $entry->title, $entry->sid,
    $entry->affiliation, $entry->author_list, $entry->issn,
    $entry->precis, $entry->publication, $entry->pub_date, $entry->url,
    $entry->grants ,$entry->url ) =~ s{<[^>]+>}{}mxsg;

  ##no critic (ImplicitNewlines)
  if( $flag eq 'update' ) {
    my $result_flag = $self->query( '
      update entry
         set pubmed    = ?, doi         = ?, pmc         = ?, title       = ?, sid = ?,
             xml       = ?, _title      = ?, affiliation = ?, author_list = ?, url = ?,
             issn      = ?, publication = ?, links       = ?, pub_date    = ?,
             abstract  = ?, reparse_at  = ?, updated_at  = ?, grants      = ?,
             class_id    = ?
       where id = ?',
      $entry->pubmed,   $entry->doi,         $entry->pmc,         $entry->title, $entry->sid,
      $entry->xml,      $entry->sort_title,  $entry->affiliation, $entry->author_list, $entry->url,
      $entry->issn,     $entry->publication, $entry->links,       $entry->pub_date,
      $entry->precis,   $entry->reparse_at,  $now,                $entry->grants,
      $entry->class_id,
      $entry->id,
    );
    $self->query( 'update search set string = ? where id=?', $search, $entry->id ) if $result_flag;
    return $result_flag;
  }

  my $id = $self->insert( '
    insert ignore into entry (
      pubmed,      doi,         pmc,         title, sid,
      xml,         _title,      affiliation, author_list, url,
      issn,        publication, links,       pub_date,
      abstract,    reparse_at,  created_at,  updated_at,
      grants,      class_id
    ) values(
      ?,?,?,?,?,
      ?,?,?,?,?,
      ?,?,?,?,
      ?,?,?,?,
      ?,?
    )', 'entry', 'id',
    $entry->pubmed, $entry->doi,         $entry->pmc,         $entry->title,  $entry->sid,
    $entry->xml,    $entry->sort_title,  $entry->affiliation, $entry->author_list, $entry->url,
    $entry->issn,   $entry->publication, $entry->links,       $entry->pub_date,
    $entry->precis, $entry->reparse_at,  $now,                $now,
    $entry->grants, $entry->class_id );
  if( $id ) {
    $entry->set_id( $id );
    $self->query( 'insert ignore into search (id,string) values(?,?)', $id, $search );
  }
  return $id;
  ##use critic
}

sub get_year_counts_for_tag {
  my( $self, $tag ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash( q(
    select year(e.pub_date) as yr, count(*) as entries
      from entry e, tag_entry te, tag t
     where te.tag_id = t.tag_id and te.entry_id = e.id and t.code = ?
     group by yr
     order by yr), $tag );
  ## use critic
}

sub get_tags_for {
  my( $self, $owner ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash( q(
    select t.*, count(distinct te.entry_id) as entries
      from (tag t, tag_owner tow) left join tag_entry te on te.tag_id = t.tag_id
     where tow.tag_id = t.tag_id and tow.owner = ?
     group by t.tag_id
     order by t.type, t.name), $owner );
  ## use critic
}

sub get_tags_by_dbid {
  my( $self, $dbid, $owner ) = @_;
  ## no critic (ImplicitNewlines)
  return $self->all_hash( q(
    select t.*, if(isnull(tow.owner),0,1) as owner, if(isnull(te.tag_id),0,1) as tagged
  from ( tag t left join tag_owner tow on tow.tag_id = t.tag_id and tow.owner = ?)
       left join tag_entry te on te.entry_id = ? and te.tag_id = t.tag_id
 order by t.type, t.name), $owner, $dbid );
  ## use critic
}

sub get_all_tags {
  my $self = shift;
  ##no critic (ImplicitNewlines)
  return $self->all_hash( q(
    select t.*, count(distinct te.entry_id) as entries,
           group_concat( distinct tow.owner order by owner ) as owners
      from ( tag as t left join tag_entry as te on te.tag_id = t.tag_id )
      left join tag_owner as tow on tow.tag_id = t.tag_id
     group by t.tag_id
     order by t.type, t.name, t.code
  ) );
  ## use critic
}

sub get_tag_by_id {
  my ( $self, $tag_id ) = @_;
  my $a_ref = $self->row_hash( 'select * from tag where tag_id = ?', $tag_id );
  return unless $a_ref;
  $a_ref->{'owners'} = $self->col( 'select owner from tag_owner where tag_id = ?', $tag_id );
  return $a_ref;
}

sub get_tag_by_code {
  my ( $self, $code ) = @_;
  my $a_ref = $self->row_hash( 'select * from tag where code = ?', $code );
  return unless $a_ref;
  $a_ref->{'owners'} = $self->col( 'select owner from tag_owner where tag_id = ?', $a_ref->{'tag_id'} );
  return $a_ref;
}

sub store_tag {
  my( $self, $tag_object ) = @_;
  if( exists $tag_object->{'tag_id'} && $tag_object->{'tag_id'} ) {
    $self->query( 'update tag set code = ?, name = ?, type = ? where tag_id = ?',
      @{$tag_object}{qw(code name type tag_id)} );
  } else {
    $self->query( 'insert ignore into tag (code,name,type,data) values(?,?,?,?)',
      @{$tag_object}{qw(code name type)},q({}) );
    $tag_object->{'tag_id'} = $self->sv('select tag_id from tag where code = ?',$tag_object->{'code'});
  }
  return $tag_object->{'tag_id'};
}

sub get_ids_for_tag {
  my ( $self, $tag ) = @_;
  ##no critic (ImplicitNewlines)
  my $a_ref = $self->all_hash( q(
    select if(isnull(e.pubmed), concat('SID_',e.sid), e.pubmed ) as k,
           year(e.pub_date) as pub_year, te.flag
      from entry e, tag_entry te, tag t
     where e.id=te.entry_id and te.tag_id=t.tag_id and te.flag in ('yes','selected') and t.code = ?
     order by pub_date desc, pubmed desc
    ),
    $tag );
  ##use critic
  my $return = { 'years' => {}, 'selected' => [], 'all' => [] };
  foreach ( @{$a_ref} ) {
    push @{ $return->{'years'}{$_->{'pub_year'}} }, $_->{'k'};
    push @{ $return->{'all'}                     }, $_->{'k'};
    push @{ $return->{'selected'}                }, $_->{'k'} if $_->{'flag'} eq 'selected';
  }
  return $return;
}

sub update_tag_entry {
  my( $self, $tag, $ref, $action ) = @_;
  my $tag_id = $self->sv( 'select tag_id from tag where code = ?', $tag );
  return 0 unless $tag_id;

  my $ref_id;
  if( $ref =~ m{\Adbid(\d+)}mxs ) {
    $ref_id = $1;
  } elsif( $ref =~ m{\ASID_(\d+)}mxs ) {
    $ref_id = $self->sv( 'select id from entry where sid = ?', $1 );
  } else {
    $ref_id = $self->sv( 'select id from entry where pubmed = ?', $ref );
    unless( $ref_id ) {
      my $xml         = $self->fetch_pubmed_xml($ref);
      my $tmp_entries = $self->parse_pubmed_xml($xml);
      foreach ( @{$tmp_entries} ) {
        $self->write_to_db( $_, 'insert' );
      }
      $ref_id = $self->sv( 'select id from entry where pubmed = ?', $ref );
    }
  }
  return 0 unless $ref_id;
  if( $action eq 'add' ) {
    $self->query( 'insert ignore into tag_entry ( tag_id, entry_id, flag, created_at ) values( ?, ?, "yes", ?)',
      $tag_id, $ref_id, $self->now );
  } elsif( $action eq 'delete' ) {
    $self->query( 'delete from tag_entry where tag_id = ? and entry_id = ?',
      $tag_id, $ref_id );
  } else {
    $self->query( 'update tag_entry set updated_at = ? where tag_id = ? and entry_id = ?',
      $self->now, $tag_id, $ref_id );
  }
  return 1;
}

sub update_tag_owner {
  my( $self, $tag_id, $owner, $action ) = @_;
  if( $action eq 'add' ) {
    $self->query( 'insert ignore into tag_owner ( tag_id, owner ) values( ?, ? )',
      $tag_id, $owner );
  } elsif( $action eq 'delete' ) {
    $self->query( 'delete from tag_owner where tag_id = ? and owner = ?',
      $tag_id, $owner );
  }
  return 1;
}
sub get_entries_by_tag {
  my ( $self, $tag, $yr ) = @_;
  ##no critic (ImplicitNewlines)
  my @pars  = ( $tag );
  my $where = q();
  if( defined $yr && $yr ) {
    $where = ' and pub_date between ? and ?';
    push @pars, "$yr-00-00", "$yr-12-31";
  }
  my $a_ref = $self->all_hash( q(
  select if(e.reparse_at < now(),1,0) as fetch_from_db, e.id,
         e.pubmed, e.doi, e.pmc, e.sid, e.title, e.url,
         e.pub_date, e._title, e.author_list, e.affiliation,
         e.publication, e.links, e.issn, e.abstract, e.grants
    from entry e, tag_entry as te, tag as t
   where e.id=te.entry_id and te.tag_id = t.tag_id and t.code = ? and te.flag in ('yes','selected')
  ).$where, @pars );
  ##use critic
  my $return = [];
  foreach ( @{$a_ref} ) {
    push @{$return}, Pagesmith::Object::Reference->new( $_ );
  }
  return $return;
}

sub non_pubmed_ids {
  my $self = shift;
  return $self->col( 'select concat("SID_",sid) from entry where isnull(pubmed)');
}

sub search_ids {
  my ( $self, $string, $no_pubmed ) = @_;
  ##no critic (ImplicitNewlines)
  my $where = $no_pubmed ? 'and isnull(e.pubmed)' : q();
  return $self->col( "
  select ifnull(e.pubmed, concat('SID_',e.sid) )
    from entry e, search s
   where e.id = s.id and match( s.string ) against ( ? ) $where
   limit 100
  ", $string );
}

sub create {
  my( $self, $hash_ref ) = @_;
  return Pagesmith::Object::Reference->new( $hash_ref );
}

sub create_from_tmp {
  my( $self, $hash_ref ) = @_;
  return Pagesmith::Object::Reference->new_from_tmp( $hash_ref );
}

sub fetch_by_dbid {
  my ($self, $dbid) = @_;
  my ($refs) = $self->fetch_from_db( 'id', $dbid);
  return unless keys %{$refs};
  return unless exists $refs->{$dbid};
  return $refs->{$dbid};
}

sub fetch_from_db {
  my ( $self, $type, @ids ) = @_;
  return ( {}, \@ids ) unless $self->dbh;

  my $qs = join q(,), map { q(?) } @ids;
  ##no critic (ImplicitNewlines)
  my $a_ref = $self->all_hash( "
  select e.id, if(e.reparse_at < now(),1,0) as fetch_from_db,
         e.pubmed, e.doi, e.pmc, e.sid, e.title, e.url,
         e.pub_date, e._title, e.author_list, e.affiliation,
         e.publication, e.links, e.issn, e.abstract, e.grants, e.class_id,
         c.code as class_code, c.name as class_name, e.url
    from entry e, class c
   where $type in ($qs)", @ids );
  ##use critic (ImplicitNewlines)
  my $return = {};
  my %to_fetch = map { ( $_ => 1 ) } @ids;
  foreach ( @{$a_ref} ) {
    $return->{ $_->{$type} } = $self->create($_);
    delete $to_fetch{ $_->{$type} } unless $_->{'fetch_from_db'};
  }
  return ( $return, [keys %to_fetch] );
}

##no critic (ExcessComplexity)
sub parse_pubmed_xml {
  my $self = shift;
  local $_ = shift;
  my $res = [];
  return $res unless $_;
  utf8::decode($_); ##no critic (CallsToUnexportedSubs)
  foreach my $pa (m{<PubmedArticle>(.*?)</PubmedArticle>}mxsg) { ## no critic (UnusedCapture)
    local $_ = $pa;
    my $block = { 'xml' => "<PubmedArticle>$_</PubmedArticle>" };
    if (m{<MedlineCitation.*?>(.*?)</MedlineCitation>}mxs) {
      local $_ = $1;
      if( m{<PMID>(\d+)</PMID>}mxs ) {
        $block->{'ids'}{'pubmed'} = $self->_decode($1);
      }
      if (m{<Article.*?>(.*?)</Article>}mxs) {
        local $_ = $1;
        if (m{<ArticleTitle>(.*?)</ArticleTitle>}mxs) {
          $block->{'title'} = $self->_decode($1);
        }
        if (m{<Affiliation>(.*?)</Affiliation>}mxs) {
          $block->{'affiliation'} = $self->_decode($1);
        }
        if (m{<Pagination>(.*?)</Pagination>}mxs) {
          local $_ = $1;
          if( m{<MedlinePgn>(.*?)</MedlinePgn>}mxs ) {
            $block->{'pages'} = $self->_decode($1);
          }
        }
        if (m{<Abstract>(.*?)</Abstract>}mxs) {
          local $_ = $1;
          $block->{'abstract'} = q();
          ## no critic (ProhibitDeepNests)
          while( s{<AbstractText([^>]*)>(.*?)</AbstractText>}{}mxs ) {
            my $flags = $1;
            my $text  = encode_entities( $self->_decode( $2 ) );
            if( $flags =~ m{Label="(\w+)"}mxs ) {
              $block->{'abstract'} .= sprintf '<p class="abstract"><strong>%s</strong>: %s</p>',
                encode_entities(ucfirst lc $1),
                $text;
            } else {
              $block->{'abstract'} .= '<p class="abstract">'.$text.'</p>';
            }
          }
          ## use critic
        }
        if (m{<GrantList(.*?)>(.*?)</GrantList>}mxs) {
          local $_ = $2;
          if( $1 =~ m{\s*CompleteYN="(N)"}mxs ) {
            $block->{'grants_incomplete'} = 1;
          }
          foreach my $gr (m{<Grant>(.*?)</Grant>}mxsg) { ## no critic (UnusedCapture)
            my $agency = $gr =~ m{<Agency>(.*?)</Agency>}mxs ? $1 : 'Unspecified';
            $block->{'grants'}{$agency}{ $gr =~  m{<GrantID>(.*?)</GrantID>}mxs ? $1 : q(-) }++;
          }
        }
        if (m{<AuthorList(.*?)>(.*?)</AuthorList>}mxs) {
          local $_ = $2;
          $block->{'authors_incomplete'} = 1 if $1 =~ m{\s+CompleteYN="(N)"}mxs;
          foreach my $au (m{<Author(.*?>.*?)</Author>}mxsg) { ## no critic (UnusedCapture)
            my $author = {};
            ##no critic (ProhibitDeepNests)
            if($au =~ m{<CollectiveName>(.*?)</CollectiveName>}mxs) {
              $author->{'name'} = $1;
              $author->{'type'} = 'collective';
            } else {
              $author->{'type'} = 'individual';
              if ($au =~ m{\A\s+ValidYN="([^"]+)">}mxs) {
                $author->{'valid'} = $self->_decode($1)||q();
              }
              if ($au =~ m{<LastName>(.*?)</LastName>}mxs) {
                $author->{'last'} = $self->_decode($1)||q();
              }
              if ($au =~ m{<ForeName>(.*?)</ForeName>}mxs) {
                $author->{'first'} = $self->_decode($1)||q();
              }
              if ($au =~ m{<Initials>(.*?)</Initials>}mxs) {
                $author->{'init'} = $self->_decode($1)||q();
              }
              $author->{'name'} = exists $author->{'init'} ? "$author->{'last'} $author->{'init'}" : $author->{'last'};
            }
            ##use critic
            push @{ $block->{'authors'} }, $author;
          }
        }
        if (m{<Journal>(.*?)</Journal>}mxs) {
          local $_ = $1;
          ( $block->{'issn_type'}, $block->{'issn'} ) = ( $self->_decode($1), $self->_decode($2) )
            if m{<ISSN\s+IssnType="(\w+)">(.*?)</ISSN>}mxs;
          if (m{<Title>(.*?)</Title>}mxs) {
            $block->{'journal'} = $self->_decode($1);
          }
          if (m{<JournalIssue.*?>(.*?)</JournalIssue>}mxs) {
            local $_ = $1;
            ##no critic (ProhibitDeepNests)
            if (m{<Volume>(.*?)</Volume>}mxs) {
              $block->{'volume'} = $self->_decode($1);
            }
            if (m{<Issue>(.*?)</Issue>}mxs) {
              $block->{'issue'} = $self->_decode($1);
            }
            if (m{<PubDate>(.*?)</PubDate>}mxs) {
              local $_ = $1;
              if (m{<MedlineDate>(\d+)\s+(\w+)\s+([-\d]+)</MedlineDate>}mxs) {
                $block->{'year'}  = $1;
                $block->{'month'} = $2;
                $block->{'day'}   = $3;
              } elsif (m{<MedlineDate>(\d+)\s+(\w+)-\w+</MedlineDate>}mxs) {
                $block->{'year'}  = $1;
                $block->{'month'} = $2;
                $block->{'day'}   = q();
              } else {
                if (m{<Year>(.*?)</Year>}mxs) {
                  $block->{'year'}  = $self->_decode($1);
                }
                if (m{<Month>(.*?)</Month>}mxs) {
                  $block->{'month'} = $self->_decode($1);
                }
                if (m{<Day>(.*?)</Day>}mxs) {
                  $block->{'day'}   = $self->_decode($1);
                }
              }
            }
            ##use critic (ProhibitDeepNests)
          }
        }
      }
      foreach (m{<OtherID(.*?>.*?)</OtherID>}mxs) {
        $block->{'ids'}{'pmc'} = $1 if m{>PMC(\d+)\Z}mxs;
      }
    }
    if (m{<PubmedData>(.*?)</PubmedData>}mxs) {
      local $_ = $1;
      if (m{<ArticleIdList>(.*?)</ArticleIdList>}mxs) {
        local $_ = $1;
        foreach my $ail ( m{<ArticleId\s+IdType="(\w+">[^>]+?)</ArticleId>}mxgs ) { ## no critic (UnusedCapture)
          if( $ail =~ m{\A(.*?)">(.*)\Z}mxs) {
            $block->{'ids'}{$1} = $self->_decode($2);
          }
        }
      }
    }
    push @{$res}, Pagesmith::Object::Reference->create_from_xml($block);
  }
  return $res;
}
##use critic (ExcessComplexity)
sub _decode {
  my ( $self, $string ) = @_;
  return decode_entities($string);
}

sub _doi_to_pubmed {
  my ( $self, @dois ) = @_;
  my $search_query = join '+or+', map { sprintf 'term=%s[doi]', uri_escape_utf8($_) } @dois;
  my $url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&id='.$search_query;
  $ua->proxy( 'http', $self->{'_proxy_url'} );
  my $response = get $url;
  my @ids = $response =~ m{<Id>(\d+)</Id>}mxgs;
  return @ids;
}

sub fetch_pubmed_xml {

#@param string+ String of pubmed IDs
  my ( $self, @ids ) = @_;
  my $url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.cgi?db=pubmed&retmode=xml&rettype=abstract&id='.
    join q(,), grep { m{\A\d+\Z}mxs } @ids;
  $ua->proxy( 'http', $self->{'_proxy_url'} );
  return get $url;
}

## consider using www.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=10.1038/nature09298[doi] to convert doi ->pubmed

sub author_entry_array {
  my ( $self, $id ) = @_;
  return $self->all_hash( 'select a.*,ae.flag from author as a left join author_entry as ae on a.id=ae.tag_id and ae.entry_id=?', $id );
}

sub get_classes {
  my $self = shift;
  return $self->all_hash( 'select class_id, code, name from class order by name' );
}

sub pop_class_cache {
  my $self = shift;
  $self->{'class_cache'} = { map { ($_->{'class_id'} => $_) } @{$self->get_classes} } unless exists $self->{'class_cache'};
  return $self;
}

sub get_class_name {
  my( $self, $id ) = @_;
  $self->pop_class_cache;
  return $self->{'class_cache'}{$id}{'name'}||'Unclassified';
}

sub get_class_code {
  my( $self, $id ) = @_;
  $self->pop_class_cache;
  return $self->{'class_cache'}{$id}{'code'}||'unclassified';
}
1;
