package Pagesmith::Object::Reference;

## Object representing reference
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

use Readonly qw(Readonly);
Readonly my $ONE_MONTH => 31;
Readonly my $ONE_WEEK  => 7;
Readonly my $ONE_DAY   => 86_400;
Readonly my $YR_OFFSET => 1_900;
Readonly my $DEFAULT_MAX_AUTHORS => 1_000_000;

use Encode::Unicode;
use HTML::Entities qw(encode_entities);
use URI::Escape qw(uri_escape_utf8);
use utf8;

sub new {
  my( $class, $pars ) = @_;
  my $self  = { %{$pars} };
  $self->{'max_authors'} = $DEFAULT_MAX_AUTHORS;
  bless $self, $class;
  return $self;
}

sub new_from_tmp {
  my($class,$pars ) = @_;
  my $pmc;
  if ( exists $pars->{'ids'}{'pmc'} && defined $pars->{'ids'}{'pmc'} ) {
    ( $pmc = $pars->{'ids'}{'pmc'} ) =~ s{\APMC}{}mxs;
  }
  my $self = {
    'doi'         => $pars->{'ids'}{'doi'},
    'pmc'         => $pmc,
    'key'         => $pars->{'key'},
    'class_id'    => $pars->{'class_id'}  ||1,
    'class_name'  => $pars->{'class_name'}||q(),
    'class_code'  => $pars->{'class_code'}||q(),
    'url'         => $pars->{'url'},
    'issn'        => encode_entities( $pars->{'issn'} ),
    'title'       => encode_entities( $pars->{'title'} ),
    'abstract'    => encode_entities( $pars->{'abstract'} ),
    'affiliation' => encode_entities( $pars->{'affiliation'} ),
    '_raw'        => $pars,
  };
  $self->{'max_authors'} = $DEFAULT_MAX_AUTHORS;
  bless $self, $class;

  return $self->touch_values;
}

sub touch_values {
  my $self = shift;
  $self->{'pub_date'}    = $self->_pub_date;
  $self->{'author_list'} = $self->_author_list;
  $self->{'links'}       = $self->_links;
  $self->{'grants'}      = $self->_grants;
  $self->{'publication'} = $self->_publication;
  return $self;
}

sub _month {
  my($self,$x) = @_;
  my %months = qw(
    Jan 1 Feb 2 Mar 3 Apr 4 May 5 Jun 6 Jul 7 Aug 8 Sep 9 Oct 10 Nov 11 Dec 12
  );
  return 0 unless $x;
  return $x if $x =~ m{\A\d+\Z}mxs;
  return $x =~ m{\A(\w{3})}mxs ? $months{$1} : 0;
}

sub update_from_json {
  my($self,$json ) = @_;
  my $pmc;
  if ( exists $json->{'pmc'} ) {
    ( $pmc = $json->{'pmc'} ) =~ s{\APMC}{}mxs;
  }
  $self->{'pmc'} = $pmc;

  $self->{'pubmed'}      = $json->{'pubmed'};
  $self->{'doi'}         = $json->{'doi'};
  $self->{'pmc'}         = $pmc;
  $self->{'class_id'}    = encode_entities( $json->{'class_id'} );
  $self->{'url'}         = encode_entities( $json->{'url'} );
  $self->{'issn'}        = encode_entities( $json->{'issn'} );
  $self->{'title'}       = encode_entities( $json->{'title'} );
  delete $self->{'_title'} unless $json->{'title'} eq $self->{'title'};
  $self->{'abstract'}    = encode_entities( $json->{'abstract'} );
  $self->{'affiliation'} = encode_entities( $json->{'affiliation'} );
  $self->{'_raw'}        = $json;

  return $self->touch_values;
}

sub create_from_xml {
  my($class,$pars ) = @_;
  my $pmc;
  if ( exists $pars->{'ids'}{'pmc'} ) {
    ( $pmc = $pars->{'ids'}{'pmc'} ) =~ s{\APMC}{}mxs;
  }
  my $self = {
    'pubmed'      => $pars->{'ids'}{'pubmed'},
    'doi'         => $pars->{'ids'}{'doi'},
    'pmc'         => $pmc,
    'xml'         => $pars->{'xml'},
    'issn'        => encode_entities( $pars->{'issn'} ),
    'title'       => encode_entities( $pars->{'title'} ),
    'affiliation' => encode_entities( $pars->{'affiliation'} ),
    'class_id'    => 1,
    'class_code'  => q(),
    'class_name'  => q(),
    '_raw'        => $pars,
  };
  $self->{'abstract'} = $pars->{'abstract'}=~m{\A<}mxs ?  $pars->{'abstract'} : encode_entities( $pars->{'abstract'} )
    if exists $pars->{'abstract'} && defined $pars->{'abstract'};
  $self->{'max_authors'} = $DEFAULT_MAX_AUTHORS;

  bless $self, $class;

  return $self->touch_values;
}

## Direct accessors for database columns!
sub set_id {
  my( $self, $id ) = @_;
  $self->{'id'} = $id;
  return $self;
}

sub id {
  my $self = shift;
  return $self->{'id'};
}

sub class_id {
  my $self = shift;
  return $self->{'class_id'};
}

sub class_code {
  my $self = shift;
  return $self->{'class_code'};
}

sub class_name {
  my $self = shift;
  return $self->{'class_name'};
}

sub set_class_id {
  my( $self, $class_id ) = @_;
  $self->{'class_id'}   = $class_id;
  return $self->{'class_id'};
}

sub sid {
  my $self = shift;
  return $self->{'sid'};
}

sub set_sid {
  my( $self, $sid ) = @_;
  return $self->{'sid'}=$sid;
}

sub pubmed {
  my $self = shift;
  return $self->{'pubmed'};
}

sub set_pubmed {
  my( $self, $pubmed ) = @_;
  return $self->{'pubmed'}=$pubmed;
}


sub doi {
  my $self = shift;
  return $self->{'doi'};
}

sub key {
  my $self = shift;
  return $self->{'key'};
}

sub pmc {
  my $self = shift;
  return $self->{'pmc'};
}

sub xml {
  my $self = shift;
  return $self->{'xml'};
}

sub url {
  my $self = shift;
  return $self->{'url'};
}

sub set_url {
  my( $self, $url ) = @_;
  return $self->{'url'} = $url;
}

sub issn {
  my $self = shift;
  return $self->{'issn'};
}

sub title {
  my $self = shift;
  return $self->{'title'};
}

sub precis {
  my $self = shift;
  return $self->{'abstract'};
}

sub grants {
  my $self = shift;
  return $self->{'grants'};
}

sub author_list {
  my $self = shift;
  return $self->{'author_list'};
}

sub author_list_short {
  my $self = shift;
  my $flag = (my $al = $self->author_list) =~ s{</span>.*</span>}{</span>}mxs;
  $al .= ' <em>et al.</em>' if $flag && $al !~ m{<em>et al.</em>}mxs;
  return $al;
}

sub affiliation {
  my $self = shift;
  return $self->{'affiliation'};
}

sub links {
  my $self = shift;
  return $self->{'links'};
}

sub publication {
  my $self = shift;
  return $self->{'publication'};
}

sub pub_date {
  my $self = shift;
  return $self->{'pub_date'};
}

sub created_at {
  my $self = shift;
  return $self->{'created_at'};
}

sub updated_at {
  my $self = shift;
  return $self->{'updated_at'};
}

sub _pub_date {
  my $self = shift;
  my $day = ($self->{'_raw'}{'day'}||0) =~ m{\A(\d+)}mxs ? $1 : 1;
  return q() unless exists $self->{'_raw'}{'year'} && defined $self->{'_raw'}{'year'};
  return $self->{'_raw'}{'year'} if $self->{'_raw'}{'year'} eq 'In print';
  return sprintf '%04d-%02d-%02d', $self->{'_raw'}{'year'}||0, $self->_month( $self->{'_raw'}{'month'} )||0, $day||0;
}

sub sort_title {
  my $self = shift;
  unless( exists $self->{'_title'} ) {
    ( my $_title = $self->title ) =~ s{\W+}{ }mxgs;
    $_title =~ s{\A\s}{}mxs;
    $_title =~ s{\s\Z}{}mxs;
    $_title =~ s{\A(A|An|The)\b(.*)$}{$2, $1}mxis; # Remove Leading A, An, The and put it at the end....
    $self->{'_title'} = lc $_title;
  }
  return $self->{'_title'};
}

sub reparse_at {
  my $self = shift;
  my $t = ( $self->pmc && $self->doi ) ? $ONE_MONTH : $ONE_WEEK;
  my ( $s, $m, $h, $dy, $mn, $yr ) = gmtime $t * $ONE_DAY + time;
  return sprintf '%04d-%02d-%02d %02d:%02d:%02d', $yr + $YR_OFFSET, $mn + 1, $dy, $h, $m, $s;
}

sub _links {
  my $self  = shift;
  my @t;
  my %links = qw(
    pubmed http://www.ncbi.nlm.nih.gov/pubmed/%s
    doi    http://dx.doi.org/%s
    pmc    http://www.ncbi.nlm.nih.gov/pmc/articles/PMC%s/?report=abstract
    url    %s
  );
  %links = qw(
    pubmed http://ukpmc.ac.uk/abstract/MED/%s
    pmc    http://ukpmc.ac.uk/articles/PMC%s
    doi    http://dx.doi.org/%s
    url    %s
  );
  foreach (qw(pubmed pmc doi)) {
    if ( $self->{$_} ) {
      push @t, sprintf '%s: <a href="%s">%s</a>',
        uc($_), encode_entities( sprintf $links{$_}, uri_escape_utf8( $self->{$_} ) ),
        encode_entities( $self->{$_} );
    }
  }
  push @t, sprintf 'URL: <%% Link -length=40 %s %%>', encode_entities( $self->{'url'} ) if $self->{'url'};
  return join '; ', @t;
}

sub _grants {
  my $self = shift;
  return q() unless exists $self->{'_raw'}{'grants'};
  my @agencies;
  foreach ( sort keys %{ $self->{'_raw'}{'grants'} } ) {
    my $grant_id_string = join ', ', map { sprintf '<span class="grant">%s</span>', encode_entities($_) }
      grep { $_ ne q(-) }
      sort keys %{ $self->{'_raw'}{'grants'}{$_} };
    push @agencies, $grant_id_string
      ? ( encode_entities($_) . q(: ) . $grant_id_string )
      : encode_entities($_);
  }
  my $html = join '; ', @agencies;
  $html .= '; ...' if exists $self->{'_raw'}{'grants_incomplete'};
  return $html;
}

sub _author_list {
  my $self = shift;
  return 'No authors listed' unless @{ $self->{'_raw'}{'authors'} || [] };
  my @T = map { sprintf '<span class="author">%s</span>', encode_entities("$_->{'name'}") } @{ $self->{'_raw'}{'authors'} };
  my $et_al = exists $self->{'_raw'}{'authors_incomplete'} && $self->{'_raw'}{'authors_incomplete'};
  if ( !$et_al && @T > 1 ) {
    my $ult = pop @T;
    my $pen = pop @T;
    push @T, "$pen and $ult" ;
  }
  my $hide_authors = 0;
  my $html = q();
  if( @T > $self->{'max_authors'}+1 ) {
    $hide_authors = 1;
    my @visible_authors = splice @T, 0, $self->{'max_authors'};
    $html .= join ', ', @visible_authors;

    $html .= '<span class="extra_authors"><em class="authors_hidden">et al.</em><span class="authors_show">';
  }
  $html = join ', ', @T;
  $html .= ' <em>et al.</em>' if $et_al;
  $html .= '</span></span>' if $hide_authors;

  return $html;
}

sub _publication {
  my $self = shift;
  my $return = exists $self->{'_raw'}{'journal'} && defined $self->{'_raw'}{'journal'}
             ? sprintf '<span class="title">%s</span>&nbsp;', encode_entities( $self->{'_raw'}{'journal'} )
             : q();
  return $return unless exists $self->{'_raw'}{'year'} && defined $self->{'_raw'}{'year'};
  if( $self->{'_raw'}{'year'} eq 'In print' ) {
    $return .= '<em>(In print)</em>';
  } else {
    $return .= sprintf '<span class="year">%d</span>',       $self->{'_raw'}{'year'}   if exists $self->{'_raw'}{'year'}   && defined $self->{'_raw'}{'year'}   && $self->{'_raw'}{'year'}   ne q();
    $return .= sprintf ';<span class="volume">%s</span>',    $self->{'_raw'}{'volume'} if exists $self->{'_raw'}{'volume'} && defined $self->{'_raw'}{'volume'} && $self->{'_raw'}{'volume'} ne q();
    $return .= sprintf ';<span class="number">%s</span>',    $self->{'_raw'}{'issue'}  if exists $self->{'_raw'}{'issue'}  && defined $self->{'_raw'}{'issue'}  && $self->{'_raw'}{'issue'}  ne q();
    $return .= sprintf ';<span class="pagerange">%s</span>', $self->{'_raw'}{'pages'}  if exists $self->{'_raw'}{'pages'}  && defined $self->{'_raw'}{'pages'}  && $self->{'_raw'}{'pages'}  ne q();
  }
  return $return;
}

1;
