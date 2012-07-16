package Pagesmith::Action::Raw;

## Dumps raw HTML of the file to the browser (syntax highlighted)
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

use base qw(Pagesmith::Action);

# Modules used by the code!
use Cwd qw(realpath);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Spec;
use HTML::Entities qw(encode_entities);
use Syntax::Highlight::HTML;

sub run {
  my $self = shift;

  ## Grab the URL (in this case from path info)
  ## and apply checks on access permissions and security...
  ## in this case map back the file to the filesystem and
  ## check it is within the document root!
  ##
  ## All should apply basic secutiy at this point.

  my $file = join q(/), $self->path_info;
  $file =~ s{\A/+}{}mxgs;

  my $root = $self->r->document_root;
  my $full_file = realpath( File::Spec->rel2abs( $file, $root ) );
  return $self->not_found unless -e $full_file;    ## Check exists and database
  return $self->forbidden
    unless substr( $full_file, 0, length $root) eq $root;    ## Check it is in the specified directories
  return $self->forbidden unless -r $full_file;       ## Die unless exists!!

  # Open the file (always use 3 element open...!)
  return $self->forbidden unless open my $fh, '<', $full_file;
  return $self->forbidden unless $fh;                ## Die unless exists!!
                                                              # Slurp file
  local $INPUT_RECORD_SEPARATOR = undef;
  ( my $i = <$fh> ) =~ s{\t}{  }mxgs;
  close $fh; ##no critic (CheckedSyscalls CheckedClose)

  # Self gives direct access to the APR object!
  my $format = $self->param('format');

  return $self->print( $i )->ok unless $format eq 'html';

  my $x    = Syntax::Highlight::HTML->new;
  my $html = $x->parse($i);

  # Highlight "Component directives" (not core in Highlight HTML...
  $html =~ s{<%(.*?)%>}{<span class="h-dir">&lt;%$1%&gt;</span>}mxsg;

  # Tell the output filter NOT to re-decorate the page!!
  # Set the type before anything else is sent!

  ##no critic (ImplicitNewlines)
  return $self->no_decor->html->printf( '<html>
<head>
  <title>Source of %s</title>
  <link rel="stylesheet" type="text/css" href="/developer/css/html-syntax.css" />
</head>
<body>
  %s
</body>
</html>',
    encode_entities("/$file"),
    $html )->ok;
  ##use critic (ImplicitNewlines)
}

1;
