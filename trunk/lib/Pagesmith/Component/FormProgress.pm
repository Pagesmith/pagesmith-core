package Pagesmith::Component::FormProgress;

## Produces form progress in RHS panel
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

use HTML::Entities qw(encode_entities);

sub usage {
  return {
    'parameters'  => '{key}',
    'description' => 'Display the progress panel for a form...',
    'notes'       => [ 'Must appear after <% Form %> in page flow - usually in the RHS' ],
  };
}
sub execute {
  my $self = shift;

  my $key = $self->next_par()||q();

  my $progress = $self->get_store( "form_progress-$key" );
  return unless $progress;

  my $html = sprintf qq(\n      <div class="panel">\n        <h3>%s</h3>\n        <ul class="bullet">), encode_entities( $progress->{'caption'} );
  foreach ( @{ $progress->{'pages'} } ) {
    if ($_) {
      $html .= $_->{'href'}
        ? sprintf qq(\n          <li><a href="%s">%s</a></li>), encode_entities( $_->{'href'} ), $_->{'caption'}
        : sprintf qq(\n          <li>%s</li>), $_->{'caption'};
    } else {
    }
      $html .= qq(\n        </ul>\n        <ul class="bullet" style="padding-top:1em">);
  }
  $html .= qq(\n        </ul>\n      </div>);
  return $html;
}

1;

__END__

h3. Currently under development

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

* Form component

h3. Examples

h3. Developer notes

