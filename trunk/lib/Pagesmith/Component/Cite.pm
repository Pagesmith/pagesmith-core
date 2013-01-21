package Pagesmith::Component::Cite;

## Inserts a citation reference into the page, and pushes the reference into the list to be displayed in a References component block.
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

use base qw(Pagesmith::Component);

use Cwd qw(cwd realpath);
use File::Basename;
use File::Spec;
use HTML::Entities qw(encode_entities);
use utf8;

my $wrap_map = {
  'square' => [ q([), q(]), ],
  'round'  => [  '(',  ')', ],
  'none'   => [ q(),   q()  ],
};

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{SID_\d+|tmp-key|pmid}+',
    'description' => 'Includes a citation link within the body of the page, for which the reference will be displayed later',
    'notes'       => ['Can have one or more IDs', 'displays errors in logs if ID type is not recognised'],
  };
}

sub define_options {
  my $self = shift;
   return  (
     { 'code' => 'style',     'defn' => '=s', 'default' => 'footnote',  'description' => 'Style to display citation in' },
     { 'code' => 'delimiter', 'defn' => '=s', 'default' => 'square',    'description' => 'Symbols to wrap around entry - one of square, round, none'},
     { 'code' => 'name',      'defn' => q(),                            'description' => 'meta style -> inline/refname & round'},
     { 'code' => 'group',     'defn' => '=s', 'default' => 'default',   'description' => 'Key for group of references to be displayed in' },
  );
}

sub execute {
  my $self = shift;

  my $style_flag = $self->option('style',     'footnote' );
  my $delim_flag = $self->option('delimiter', 'square' );
     $style_flag = 'inline refname' if $self->option( 'name' );
     $delim_flag = 'round'          if $self->option( 'name' );
  my $style = $self->init_store( 'refstyle',  $style_flag );
  my $wrap  = $self->init_store( 'delimiter', $delim_flag );

  my $key = 'references-'.$self->option('group','default');
  my $ref_hash = $self->init_store( $key, {} );

  my $tmp_references = { map { $_->{'key'} ? ($_->{'key'},1) : () } @{ $self->get_store('tmp_refs') || [] } };
  my @links;
  my @errors;
  foreach my $id ( $self->pars ) {
    if ( $id =~ m{\ASID_\d+\Z}mxs ) {
      $ref_hash->{$id} ||= 1 + keys %{$ref_hash};
      push @links, qq(<a href="#$id">$id</a>);
    } elsif ( $tmp_references->{$id} ) {
      push @links, qq(<a href="#tmp_$id">$id</a>);
      $ref_hash->{$id} ||= 1 + keys %{$ref_hash};
    } elsif ( $id =~ m{\A\d+\Z}mxs ) {
      push @links, qq(<a href="#pubmed_$id">$id</a>);
      $ref_hash->{$id} ||= 1 + keys %{$ref_hash};
    } else {
      push @errors, $id;
    }
  }
  warn "Unrecognised citation format(s): @errors" if @errors; ## no critic (Carping)

  return q() unless @links;
  return sprintf '<span class="fncite %s"> %s%s%s</span>',
    $style,
    $wrap_map->{$wrap}[0],
    ( join q(; ), @links ),
    $wrap_map->{$wrap}[1];
}

1;
__END__

h3. Syntax

<% Cite
  -style=(footnote|refname)
  -delimiter=(round|square|none)
  -group=?
  (ID)+
%>

h3. Purpose

Creates a "citation" which links to a footnotes section on the page. takes a list of IDs: pubmed, tmp or SID of papers to include in Cite

h3. Options

* style (optional - default footnote) - format to display citations in - default is "footnote"
  is plain, if set to refname, citation reference which is initially a pubmed ID/SID gets
  replaced with either the author, authors (if 2) or author et al (if 3 or more) and the year.

* delimiter (optional - default square) - whether to wrap link in round (), square [] or no brackets

* group (string) - if you want to section footnotes then can do this by allocating a group to each citation with the group flag

h3. Notes

* Lists any un-recognisable Ids in error logs.

* Ids with valid formats but not existing will be thrown by the References module which tries to render them.

h3. See also

* Component: References

* Javascript: core/js/references.js

h3. Examples

<% Cite -style=refname -delimiter=round -group=other 1 2 3 %>

<% References -footnotes -group=other 4 %>

h3. Developer notes
