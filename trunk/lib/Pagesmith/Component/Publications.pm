package Pagesmith::Component::Publications;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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

use base qw(Pagesmith::Component::References);

use HTML::Entities qw(encode_entities);
use utf8;

use Pagesmith::Adaptor::Reference;
use Pagesmith::Object::Reference;

sub usage {
  my $self = shift;
  return {
    'parameters'  => q({year}+ or {tags}+),
    'description' => 'Put in block of references for given Year or given tag',
    'notes'       => [ 'Deprecated - see functions now in references for tags' ],
  };
}

sub define_options {
  my $self = shift;
  return $self->SUPER::define_options;
}

sub _contents {
  my( $self, $string, $options, $ref_data ) = @_;
  return sprintf qq(<h3>%s Publications</h3>\n      <%% References%s %%>),
    $string, join q( ), $options, @{ $ref_data };
}

sub execute {
  my $self = shift;

  my @indexes = $self->pars();

  my $options = q();
  foreach my $o ( keys %{ $self->options } ) {
    $options.= sprintf ' "-%s=%s"', encode_entities($o), encode_entities(defined $_ ? $_ : 1) foreach $self->option($o);
  }

  my $return = q();

  if( $indexes[0] =~ m{\A\d+\Z}mxs ) {
    ## This is a fetch by year
    my $rh = Pagesmith::Adaptor::Reference->new();
    foreach my $year ( @indexes ) {
      next if $year =~ m{\D}mxs;
      $return .= sprintf '<%% References%s %%>', join q( ),$options, @{ $rh->get_ids_for_year( $year ) };
    }
    return $return;
  } else {
    my $tag = shift @indexes;
    $tag =~ s{\W}{}mxgs;
    my $rh = Pagesmith::Adaptor::Reference->new();
    my $reference_data = $rh->get_ids_for_tag( $tag );
    my $navigation = q();
    my $contents   = q();
    my $tabs = $self->tabs( {'fake'=>1} );
    if( @{$reference_data->{'selected'}} ) {
      $self->add_tab( "sub_$tag".'_selected', 'Selected',
        $self->_contents( 'Selected', $options, $reference_data->{'selected'} ),
      );
    }
    foreach my $year ( reverse sort keys %{ $reference_data->{'years'} } ) {
      $self->add_tab( "sub_$tag".'_'.$year, $year,
        $self->_contents( $year, $options, $reference_data->{'years'}{$year} ),
      );
    }
    return q() unless $navigation;
    ## no critic (ImplicitNewlines)
    return sprintf '
<div class="panel">
  <h2>Publications</h2>
  <div class="sub_nav">
    <h3>Year</h3>
    %s
  </div>
  <div class="sub_data">
    %s
  </div>
</div>', $tabs->render_ul_block, $tabs->render_div_block;
    ## use critic
  }
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

h3. Developer Notes
