package Pagesmith::Component::Markedup;

## Component class for rendering marked up perl/html
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
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Basename qw(dirname basename);
use File::Spec;
use HTML::Entities qw(encode_entities);
use Syntax::Highlight::HTML;
use Syntax::Highlight::Perl::Improved;

use Pagesmith::ConfigHash qw(server_root);

sub define_options {
  my $self = shift;
  return (
    $self->ajax_option,
    { 'code' => 'format', 'defn' => '=s', 'default' => 'perl', 'description' => 'format of sequence' },
    { 'code' => 'number', 'defn' => '=s', 'description' => 'prefix to add to ids of each row...' },
    { 'code' => 'height', 'defn' => '=s', 'description' => 'height of box to display' },
    { 'code' => 'title',  'defn' => '=s', 'description' => 'title string to add to documentation' },
  );
}

sub usage {
  return {
    'parameters'  => '{file_name}',
    'description' => 'Mark-up file...',
    'notes' => [],
  };
}

sub ajax {
  my $self = shift;
  return $self->option('ajax');
}

sub _relative_to_serverroot {
  my $self = shift;
  return $self->option('format') eq 'perl';
}

sub filename {
  my $self = shift;
  return $self->{'_filename'};
}

sub get_filename {
  my ( $self, $fn ) = @_;
  unless ( $self->filename ) {
    my $root = $self->page->docroot;
       $root = server_root if $self->_relative_to_serverroot;
    my $filename = realpath(
      $fn =~ m{\A/(.*)\Z}mxs
      ? File::Spec->rel2abs( $1,  $root )
      : File::Spec->rel2abs( $fn, dirname( $self->page->filename ) ) );
    $self->{'_filename'} = $filename;
  }
  return $self->filename;
}

sub check_file {
  my ( $self, $fn ) = @_;
  my $filename = $self->get_filename($fn);
  return $self->error( 'Unknown filename: ' . encode_entities($fn) ) unless $filename;
  my $root = server_root;
  return $self->error( 'Forbidden invalid path: ' . encode_entities($fn) ) unless substr( $filename, 0, length $root ) eq $root;
  return $self->error( 'Unable to read file: ' . encode_entities($fn) ) unless -e $filename;
  return $self->error( 'Forbidden - no permission: ' . encode_entities($fn) ) unless -r $filename;

  return;
}

sub my_cache_key {
  my $self = shift;
  my ($fn) = $self->pars;

  my $key =
    $fn =~ m{\A/(.*)\Z}mxs
    ? File::Spec->rel2abs( $1,  $self->page->docroot )
    : File::Spec->rel2abs( $fn, dirname( $self->page->filename ) );
  while ( $key =~ s{/[^/]+/[.]{2}}{}mxgs ) {
    1;
  }
  return
      substr( $key, 0, length $self->page->docroot ) eq $self->page->docroot
    ? substr( $key, length $self->page->docroot  )
    : undef;
}

sub execute {
  my $self = shift;

  my $format = $self->option('format') || 'perl';

  my ($fn) = $self->pars;

  my $err = $self->check_file($fn);
  return $err if $err;
  return $self->error( 'Forbidden - could not open file: ' . encode_entities($fn) ) unless open my $fh, '<', $self->filename;

  my $html;
  {
    local $INPUT_RECORD_SEPARATOR = undef;
    $html = <$fh>;
  }
  close $fh; ##no critic (CheckedSyscalls CheckedClose)

  if ( $format eq 'html' ) {
    my $x = Syntax::Highlight::HTML->new;
    $html = $x->parse($html);
    $html =~ s{<%(.*?)%>}{<span class="h-dir">&lt;%$1%&gt;</span>}mxsg;
    $html =~ s{\A<pre>\s+}{}mxs;
    $html =~ s{\s+</pre>\Z}{}mxs;
  } elsif ( $format eq 'perl' ) {
    my $x  = Syntax::Highlight::Perl::Improved->new;
    my %ct = (
      'Variable_Scalar'   => 'p-sc', # '080',
      'Variable_Array'    => 'p-ar', #'f70',
      'Variable_Hash'     => 'p-hs', #'80f',
      'Variable_Typeglob' => 'p-tg', #'f03',
      'Subroutine'        => 'p-sb', #'980',
      'Quote'             => 'p-qu', #'00a;background-color:white',
      'String'            => 'p-st', #00a;background-color:white',
      'Bareword'          => 'p-bw', #f00;font-weight: bold',
      'Package'           => 'p-pa', #900',
      'Number'            => 'p-nu', #f0f',
      'Operator'          => 'p-op', #900;font-weight:bold;',
      'Symbol'            => 'p-sy', #000',
      'Keyword'           => 'p-kw', #000',
      'Builtin_Operator'  => 'p-bo', #300',
      'Builtin_Function'  => 'p-bf', #001',
      'Character'         => 'p-ch', #800',
      'Directive'         => 'p-di', #399',
      'Label'             => 'p-la', #939',
      'Line'              => 'p-li', #000',
      'Comment_Normal'    => 'p-cn', #069;background-color:#ffc',
      'Comment_POD'       => 'p-cp', #069;background-color:#ffc',
    );
    $x->define_substitution(qw(< &lt; > &gt; & &amp;));    # HTML escapes.
    # install the formats set up above
    foreach ( keys %ct ) {
      $x->set_format( $_, [qq(<span class="$ct{$_}">), '</span>'] );
    }
    $html =  $x->format_string($html);
  }
  $html =~ s{<span[^>]*></span>}{}mxgs;
  if( $html =~ m{<body>(.*)</body>}mxs ) {
    $html = $1;
  }

  if( $self->option( 'number' ) ) {
    my $line     = 0;
    my $template =  $self->option( 'number' ) =~ m{\A([[:alpha:]]+)}mxs ? qq(<span id="$1_%d" class="linenumber">%1\$5d:</span> %s\n)
                 :                                                   qq(<span class="linenumber">%5d:</span> %s\n)
                 ;
    $html = join q(),
      map { sprintf $template, ++$line,$_ }
      split m{\r?\n}mxs, $html;
  }
  my $height = $self->option('height') ? sprintf ' style="max-height: %dpx"', $self->option('height') : q();
  my $title = q();
  if( $self->option( 'title' ) ) {
    $title = $self->option('title');
    $title = q([[]]) unless $title =~ m{\[\[\]\]}mxs;
    my $filename = basename $self->filename;
    $title =~ s{\[\[\]\]}{$filename}mxsg;
    $title = sprintf '<h4>%s</h4>', $self->encode( $title );
  }
  return sprintf '%s<pre class="code" %s>%s</pre>',
    $title,
    $height,
    $html;
}

1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

