package Pagesmith::Component::Developer::Tidy;

## Insert a APR variable content into the page
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

use Pagesmith::Utils::HTMLcritic;
use HTML::Entities qw(encode_entities);    ## HTML entity escaping
use English qw($EVAL_ERROR $INPUT_RECORD_SEPARATOR -no_match_vars);
use Apache2::RequestUtil;

use Readonly qw(Readonly);
Readonly my $ACCESS_LEVEL => 1;


sub execute {
  my $self = shift;
  my $type     = 'box-info';
  my $filename = q();
  my $cleanup  = 0;
  return q() unless $self->get_store('user_can_edit');
  my $critic = $self->r->pnotes( 'critic' );

  unless( $critic ) {
    if( $self->page->filename =~ m{[.]html\Z}mxgs ) {
      $filename = $self->page->filename;
    } elsif( $self->r->notes->get( 'html' ) ) {
      $filename = $self->page->tmp_filename('html');
      my $flag = open my $fh, '>', $filename;
      if( $flag ) {
        print {$fh} $self->r->notes->get( 'html' ); ## no critic (CheckedSyscalls)
        close $fh; ## no critic (RequireChecked)
        $cleanup = 1;
      } else {
        $filename = q();
      }
    }

    return q() unless $filename;

    $critic = Pagesmith::Utils::HTMLcritic->new( $filename, $ACCESS_LEVEL );
    my $msg    = $critic->check;
    unlink $filename if $cleanup;

    return sprintf q(<div class="panel collapsed collapsible box-warn devpanel"><h3>%s</h3></div>), $msg if $msg;
  }


  unless( $critic->invalid ) {
    return sprintf q(<div class="panel collapsed collapsible box-info devpanel"><h3>This page is XHTML 1.0 compliant</h3></div>);
  }
  my $html = q();
  my @messages = $critic->messages;
  if( @messages > 0 ) {
## no critic (ImplicitNewlines)
    $html = '
<table class="sorted-table">
  <thead>
    <tr>
      <th>Level</th>
      <th>Line</th>
      <th>Col</th>
      <th>Text</th>
    </tr>
  </thead>
  <tbody>';
    foreach( @messages) {
      my $msgs;
      if( $_->{'level'} eq 'Access' ) {
        $msgs = join q(), map { m{\[(\d+[.]\d+[.]\d+[.]\d+)\]:\s+(.*)\Z}mxgs ?
          sprintf '<dt>%s %d: %s</dt><dd>%s</dd>', @{$critic->access_level($1)}, $1, encode_entities($2) :
          sprintf '<dt>*</dt><dd>%s</dd>', $_
        } @{ $_->{'messages'} };
        $msgs = qq(<dl class="twocol">$msgs</dl>);
      } else {
        $msgs = join '<br />', map { encode_entities( $_ ) } @{$_->{'messages'}};
      }
      $html .= sprintf '
    <tr class="tidy-%s">
      <td class="c">%s</td>
      <td class="r">%d</td>
      <td class="r">%d</td>
      <td>%s</td>
    </tr>',
        lc $_->{'level'}, $_->{'level'},
        $_->{'line'}, $_->{'column'},
        $msgs;
    }
    $html .= q(
  </tbody>
</table>);
## use critic
  }
  if( $critic->xml_error ) {
    $html .= sprintf '<h4>XML not well formed</h4><pre>%s</pre>',
      encode_entities( $critic->xml_error );
  }

## no critic (ImplicitNewlines)
  return sprintf q(
<div class="panel box-%s collapsible collapsed devpanel">
  <h3>HTMLTidy: %d errors / %d warnings / %d info / %d access - %s</h3>
  %s
</div>),
    $critic->level,
    $critic->n_errors,
    $critic->n_warnings,
    $critic->n_info,
    $critic->n_access,
    defined($critic->xml_error) ? 'XML is NOT well-formed' : q(),
    $html;
## use critic
}

1;

__END__

h3. Syntax

<% Developer_Tidy
%>

h3. Purpose

Display HTML "tidy" errors about the current HTML - works for both static
and dynamic content - by reporting on the HTML of the page BEFORE directives
and templating are taken into account. Also does level 1 AAA access reporting


h3. Options

None

h3. Notes

Only shows up on development sites

h3. See also

h3. Examples

<% Developer_Tidy %>
h3. Developer notes

Can be a bit quirky with directives which are within other tags - but I think
this is now fixed.
