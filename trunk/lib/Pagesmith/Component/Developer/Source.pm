package Pagesmith::Component::Developer::Source;

## Include the source of the page - including spelling checking
## Looks for an HTTP out header X-Pagesmith-NoSpell
##  * If exists and is 1 - then the source of the page is marked-up
##  * If exists and is >1 - then the source of the page is not-marked-up and the block is missed entirely
##  * If doesn't exist OR is 0 - then the source is marked up and spelling mistakes are also highlighted
##
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

use Pagesmith::Utils::Spelling;


sub execute {
  my $self = shift;
  return q() unless $self->get_store('user_can_edit');
  my $type      = 'box-info';
  my $str = $self->r->notes->get( 'html' );

  ## No HTML? arg! skip markup
  return q() unless $str;

  ## Check to see if we want to spell check the source OR mark it up at all...
  my $no_spell = $self->r->headers_out->get( 'X-Pagesmith-NoSpell' )||0;

  return q() if $no_spell > 1;

  my $message = q();
  my $spelling_errors = q();

  my $sp = Pagesmith::Utils::Spelling->new( $no_spell );

  if( $no_spell ) {
    $type = 'box-msg';
    $message = ' - spell checking skipped';
    $spelling_errors = '<p>The author of this page has forced skipping of the spell checker</p>';
  } else {

    my $return_error = $sp->check_html( $str );

    if( $return_error ) {
      return sprintf q(<div class="panel box-warn collapsed collapsible devpanel"><h3>Unable to check spelling of code - XHTML invalid</h3><pre>%s</pre></div>), $sp->{'marked_up'} || $self->encode( $str );
    }
    if( $sp->{'total_errors'} ) {
      my $diff = keys %{$sp->{'errors'}};
      my $words = join q(, ), map { $sp->{'errors'}{$_}==1 ? $_: sprintf q(%s (%d)), $_, $sp->{'errors'}{$_} } sort { lc($a) cmp lc($b) || $a cmp $b } keys %{$sp->{'errors'}};
      $type = 'box-warn';
      $message = sprintf ' - %d spelling mistakes (<span title="%s">%d words</span>)', $sp->{'total_errors'}, $words, $diff;
      $spelling_errors = sprintf '<p>Spelling errors: %s</p>', $words;
    } else {
      $message = ' - no spelling mistakes in the source';
      $spelling_errors = '<p>Please note - this only checks spelling and not grammar and context!</p>';
    }
  }
  ## no critic (ImplicitNewlines)
  return qq(<div class="panel $type collapsed collapsible devpanel"><h3>Source$message</h3>
$spelling_errors
<pre style="line-height: 1em; font-size: 0.8em">$sp->{'marked_up'}</pre></div>);
## use critic
}

1;

__END__

h3. Syntax

<% Developer_Source
%>

h3. Purpose

Marks up the source code of the webpage - and spell checks the web-page
unless the "X-Pagesmith-NoSpell" header is set

h3. Options

None

h3. Notes

h3. See also

h3. Examples

<% Developer_Source %>
h3. Developer notes

* Need to be able to add words to dictionary
