package Pagesmith::Component::References;

## Component to display nicely formatted reference lists
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

use base qw(Pagesmith::Component::Email);

use HTML::Entities qw(encode_entities);
use Readonly qw(Readonly);
use Time::HiRes qw(time);
use utf8;

use Pagesmith::Adaptor::Reference;
use Pagesmith::Object::Reference;

Readonly my $DEFAULT_RENDERER => 'ul';

##no critic (ExcessComplexity)

my %renderers = ( q(#),
qw(
            ol
  table     table
  ordered   ol
  numbered  ol
  numbers   ol
  number    ol
  ol        ol
  list      ul
  unordered ul
  ul        ul
  *         ul
  p         p
  div       p
  plain     p
) );

# In row template - %s is extra CSS generated from options, %d is an alternativ 1/2 flag to allow striping if required
my %templates = (
  'table' => [
    '<table class="references" summary="Table of refrerences"><tbody>', '<tr class="periodical%s ref_%d"><td>',
    '</td></tr>', '</tbody></table>' ],
  'p'  => ['<div class="references">', '<p class="periodical% sref_%d">',  '</p>',  '</div>'],
  'ol' => ['<ol class="references">',  '<li class="periodical%s">', '</li>', '</ol>'],
  'ul' => ['<ul class="references">',  '<li class="periodical%s">', '</li>', '</ul>'],
);

sub ajax {
  my $self = shift;
  return 0 unless $self->option('ajax');
  return $self->option( 'year' ) ? 'click' : 1;
}

sub ajax_message {
  my $self = shift;
  return sprintf '<h4 class="keep">[+] %s publications</h4>', $self->option( 'year' ) if $self->option( 'year' );
  return '<p>Retrieving references...</p>';
}

sub fetch_references {
  my $self = shift;
  my $time = time;
  my $rh = Pagesmith::Adaptor::Reference->new();
  my @ids = $self->pars;

  $self->{'cited_references'} = {};
  if( $self->option('footnotes') ) {
    my $key = 'references-'.$self->option('group','default');
    my $T = $self->get_store($key) || {};
    my @fids = sort { $T->{$a} <=> $T->{$b} } keys %{$T};    ## Preserve the order they were pushed!
    push @ids, @fids;
    $self->{'cited_references'} = { map { ($_=>1) } @fids };
    $self->remove_store($key);
  }
  my $tmp_references = $self->get_store('tmp_refs') || [];
  my @references;
  my %tmp_ref_ids;
  foreach my $hashref ( @{$tmp_references} ) {
    push @references, Pagesmith::Object::Reference->new_from_tmp( $hashref );
    $tmp_ref_ids{ $hashref->{'key'} } = 1 if exists $hashref->{'key'} && defined $hashref->{'key'};
  }
  $self->remove_store('tmp_refs');
  @ids = grep { !exists $tmp_ref_ids{ $_ } } @ids;
  my $references;
  my $missing = [];
  if( $self->option( 'tag' ) ) {
    $references = $rh->get_entries_by_tag( $self->option( 'tag' ), $self->option( 'yr' ) );
  } else {
    ( $references, $missing ) = $rh->get_entries(@ids);
  }
  if( @{$missing} ) {
    warn q(References: The following references cannot be [).$self->page->uri.q(] found: ) . join( q(; ), map { "$_->[0]:$_->[1]" } @{$missing} ) . q(.); ## no critic (Carping)
  }
  push @references, @{$references};

  return ( \@references, $missing );
}

sub execute {
  my $self = shift;
  my $time = time;
## The following code gets the references....

  my ( $references_ref, $missing_ref ) = $self->fetch_references;
  my @references = @{$references_ref||[]};
  my @missing    = map { "$_->[0]:$_->[1]" } @{$missing_ref||[]};

  my @html;
  if( $self->option( 'show_errors' ) && @missing ) {
    push @html, sprintf '<p><strong>The following references could not be found: %s</strong></p>',
      join q(, ), sort @missing;
  }

  return join q(), @html unless @references;

# Now we render the references....

  # Alias for renderers

  # Sort references
  my $sort_by = $self->option('sort_by', 'newest' );

  @references = sort { $a->_title cmp $b->_title }                                                    @references if $sort_by eq 'alpha';
  @references = sort { lc( $a->author_list ) cmp lc( $b->author_list ) || $a->_title cmp $b->_title } @references if $sort_by eq 'author';
  ##no critic (ReverseSortBlock)
  @references = sort { $a->pubmed <=> $b->pubmed || $a->sid cmp $b->sid }                             @references if $sort_by eq 'id';

  @references =
    map { $_->[1] }
    sort { $b->[0] cmp $a->[0] || $a->[1]->_title cmp $b->[1]->_title }
    map { [ $_->pub_date =~ m{\A0000-00-00}mxs ? '9999-99-99' : $_->pub_date, $_ ] }
    @references if $sort_by eq 'newest';

  ##use critic (ReverseSortBlock)
  @references =
    map { $_->[1] }
    sort { $a->[0] cmp $b->[0] || $a->[1]->_title cmp $b->[1]->_title }
    map { [ $_->pub_date =~ m{\A0000-00-00}mxs ? '9999-99-99' : $_->pub_date, $_ ] }
    @references if $sort_by eq 'oldest';


  # Select rendering style...
  my ($renderer) = $self->option('render_as');
  $renderer = $DEFAULT_RENDERER unless defined $renderer;
  $renderer = $renderers{$renderer} || $DEFAULT_RENDERER;
  my ( $start_block, $start_row, $end_row, $end_block ) = @{ $templates{$renderer} };

  push @html, $start_block unless $self->option('no_wrapper');

  # Add collapse headers
  my $extra = q();
  if ( $self->option('collapse') ) {
    $extra = ' ref-coll';
    $extra .= ' ref-closed' if $self->option('collapse') eq 'closed';
  }

  my $class             = 1;
  # Evaluate flags
  my $show_affiliations = $self->option('affiliation', 'off') ne 'off' || $self->option('full');
  my $show_abstracts    = $self->option('abstract',    'off') ne 'off' || $self->option('full');
  my $show_authors      = $self->option('authors',     'on')  ne 'off' || $self->option('full');
  my $show_first_author = $self->option('authors',     'on')  eq 'first';
  my $show_grants       = $self->option('grants',      'off') ne 'off' || $self->option('full');
  # Remove duplicates if there are any...
  my $seen              = {};

  my %link_list;
  if( $self->option('link') ) {
    %link_list =  map { ($_=>1) } $self->option('link');
  }
  my $count = 0;
  foreach my $reference (@references) {
    next if $reference->pubmed && $seen->{ 'pubmed_' . $reference->pubmed }++;
    next if $reference->sid    && $seen->{ $reference->sid                }++;
    next if $reference->key    && $seen->{ 'key:'.$reference->key         }++;

    ## Now render content - each line is rendered as a <p> tag with approriate classes for styling
    $count++;
    push @html, sprintf $start_row, $extra, $class;
    push @html, sprintf '<a id="pubmed_%s"></a>',                  $reference->pubmed if $reference->pubmed && ( $self->{'cited_references'}{$reference->pubmed} || $link_list{'pubmed'} || $link_list{'all'} );
    push @html, sprintf '<a id="%s"></a>',                         $reference->sid    if $reference->sid && ( $self->{'cited_references'}{$reference->sid} || $link_list{'sid'} || $link_list{'all'} );
    push @html, sprintf '<a id="tmp_%s"></a>',                     $reference->key    if $reference->key && ( $self->{'cited_references'}{$reference->key} || $link_list{'key'} || $link_list{'all'} );
    push @html, sprintf '<a id="pmc_%s"></a>',                     $reference->pmc    if $reference->pmc && ( $self->{'cited_references'}{$reference->pmc} || $link_list{'pmc'} || $link_list{'all'} );
    push @html, sprintf qq(\n<h4 class="article">%s</h4>),         $reference->title;

    if( $reference->doi && ( $self->{'cited_references'}{$reference->doi} || $link_list{'doi'} || $link_list{'all'} ) ) {
      (my $doi = $reference->doi ) =~ s{/}{_}mxgs;
      push @html, sprintf '<a id="doi_%s"></a>', $doi;
    }
    if( $show_authors && $reference->author_list ) {
      if( $show_first_author ) {
   $self->dumper( $references );
        push @html, sprintf qq(\n<p class="authors">%s</p>),           $self->expemail( $reference->author_list_short );
      } else {
        push @html, sprintf qq(\n<p class="authors">%s</p>),           $self->expemail( $reference->author_list );
      }
    }
    push @html, sprintf qq(\n<p class="affiliation">%s</p>),       $self->expemail( $reference->affiliation )  if $reference->affiliation  && $show_affiliations;
    if( $reference->precis && $show_abstracts ) {
      if( $reference->precis =~ m{\A<}mxs ) {
        push @html, join q(), map { m{\A<}mxs ? $_ : $self->expemail( $_ ) } split m{(<[^>]+>)}mxs, $reference->precis;
      } else {
        push @html, sprintf qq(\n<p class="abstract">%s</p>),          $self->expemail( $reference->precis );
      }
    }
    push @html, sprintf qq(\n<p class="grants">Funded by: %s</p>), $self->expemail( $reference->grants )       if $reference->grants       && $show_grants;
    push @html, sprintf qq(\n<p class="publication">%s</p>),       $reference->publication                      if $reference->publication;
    push @html, sprintf qq(\n<p class="links">%s</p>),             $reference->links                            if $reference->links;
    # Any additional markup required by inherited component...
    push @html, $self->_extra_markup( $reference );
    push @html, $end_row;
    # Flip flow highlighting class
    $class = $class == 2 ? 1 : 2;
  }
  push @html, $end_block unless $self->option('no_wrapper');
  if( $count && $self->option('include_count' ) ) {
    my $template = $self->option('include_count') || 'Number of references: %d';
    unshift @html, sprintf "<p>$template</p>", $count;
  }
  unshift @html, sprintf '<h4 class="keep">[-]%s publications</h4>', $self->option( 'year' ) if $self->option( 'year' );

  return join q(), @html;
}
##use critic (ExcessComplexity)
## Extra h
sub _extra_markup {
  my( $self, $reference ) = @_;
  return q();
}

sub expemail {
  my ( $self,$string ) = @_;
  $string =~ s{(\w[^\s;]*@\S*\w)}{$self->_safe_email( $1,$1 )}mxegs;
  return $string;
}
1;


__END__

h3. Sytnax

<% References
  -abstract[=on/off]
  -affiliation[=on/off]
  -ajax
  -authors[=on/off]
  -collapse(=closed)
  -footnotes
  -full
  -grants[=on/off]
  -group=S
  -no_wrapper
  -sort_by=(newest|oldest|alpha|author|id|raw)
  -render_as=(table|#|ol|ordered|numbered|numbers|number|*|list|unordered|ul|p|div|plain)
  -year=N

  (pmid|doi|SID)+
%>

h3. Purpose

Display a list of references - usually based on their PubMed IDs - the system
retrieves information about the PubMed entries if they are not already cached
in the references database.

h3. Options

* abstract (opt default=off) - Include abstracts in display;

* affiliation (opt default=off) - Include affiliation in display;

* ajax (opt) - Include a placeholder div for later retrieval of references via AJAX;

* authors (opt default=on) - Include authors in display;

* collapse (opt) - Entries are collapsable - by clicking on title affiliation, grants
  and abstract are hidden - if set to closed - these start hidden;

* footnotes (opt) - Display block of footnote references inserted by Cite directives;

* full (opt) - Display all information (abstratct, affiliation, authors & grants);

* grants (opt default=off) - Display grants in display;

* group (opt default=default) - Allows cross refrences <% Cite %> tags to have an associated group

* no_wrapper (opt) - Do not include ul/table/ol tags - useful if having to do
  something hacky!

* sort_by (opt default newest) - Order to sort by newest, oldest, alpha, author, id, raw;

* render_as (opt default ul) - Whether to display contents as a bulleted list, numbered list, table or blocks;

* year (opt) - Include a heading "{year} publications", and allow it to "collapse" - if this is
  included by AJAX the place holder is [+] "{year} publications" - note year may not be
  a real year but could be something like 'Other'...

h3. Notes

* Default renderer is display as list and including title, authors, journal and
  external links, and include stuff in order newest first.

h3. See Also

* Directive: Cite - generates entries within the page which link to a references
  block with flag "-footnotes"

* Directive: TmpRef - insert a temporary reference into the page

* Perl module: Pagesmith::Adaptor::Reference

* Perl module: Pagesmith::Object::Reference

* Database: reference

* Javascript: /core/js5/references.js

* CSS: /core/css/pagesmith-references.css

h3. Examples

* <% References -full -collapse=closed 1 2 3 %> - Display references 1,2,3 with full details - but initially closed

* <% References 1 2 3 %> - Display references 1,2,3

* <% References -footnotes %> - Display all citations without groups

* <% References -footnotes -group=other %> - Display all citations with group set to other

h3. Developer Notes

* Still to do implement JS/cSS to create et al link - and author exapansion!
