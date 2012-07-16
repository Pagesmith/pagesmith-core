package Pagesmith::Component::File;

## Including a file!
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
use File::Basename qw(dirname);
use File::Spec;
use HTML::Entities qw(encode_entities);

sub set_filename {
  my( $self, $value ) = @_;
  $self->{'_filename'} = $value;
  return $value;
}
sub filename {
  my $self = shift;
  return $self->{'_filename'};
}

sub ajax {
  my $self = shift;
  return $self->option('ajax') ? 1 : 0;
}

sub _get_filename {
  my ( $self, $fn ) = @_;
  unless ( $self->filename ) {
    my $filename = realpath( $fn =~ m{\A/(.*)\Z}mxs ? File::Spec->rel2abs( $1,  $self->page->docroot )
                                                    : File::Spec->rel2abs( $fn, dirname( $self->page->filename ) ) );
    $self->{'_filename'} = $filename;
  }
  return $self->filename;
}

sub check_file {
  my ( $self, $fn, $clear ) = @_;
  $self->set_filename( undef ) if $clear;
  my $filename = $self->_get_filename($fn);
  return $self->_error( 'Unknown filename: ' . encode_entities($fn) ) unless $filename;
  return $self->_error( 'Forbidden invalid path: ' . encode_entities($fn) )
    unless substr( $filename, 0, length $self->page->docroot ) eq $self->page->docroot;
  return $self->_error( 'Unable to read file: ' . encode_entities($fn) )       unless -e $filename;
  return $self->_error( 'Forbidden - no permission: ' . encode_entities($fn) ) unless -r $filename;

  return;
}

sub _cache_key {
  my $self = shift;
  my ($fn) = $self->pars;

  my $key = $fn =~ m{\A/(.*)\Z}mxs
          ? File::Spec->rel2abs( $1,  $self->page->docroot )
          : File::Spec->rel2abs( $fn, dirname( $self->page->filename ) );
  while ( $key =~ s{/[^\/]+/\.\.}{}mxgs ) {
    1;
  }
  return
      substr( $key, 0, length $self->page->docroot ) eq $self->page->docroot
    ? substr( $key,    length $self->page->docroot )
    : undef;
}

sub execute {
  my $self = shift;
  my ($fn) = $self->pars;

  my $err = $self->check_file($fn);
  return $err if $err;

  return $self->_error( 'Forbidden - could not open file: ' . encode_entities($fn) ) unless open my $fh, '<', $self->filename;
  local $INPUT_RECORD_SEPARATOR = undef;
  my $html = <$fh>;
  close $fh; ## no critic (CheckedSyscalls CheckedClose)

  $html =~ s{\A\xEF\xBB\xBF}{}mxs; ## Nasty code - we need to remove the BOM if there is one!
  $self->_parse( \$html ) if $self->option('parse');

  return $html =~ m{<body>(.*)</body>}mxs ? $1 : $html;
}

1;

__END__

<% File
  -ajax
  -parse
  Filename
%>

h3. Purpose

Include a file within the page

h3. Options

* ajax - Delay loading via AJAX

* parse - Run file back through the directive compiler, so directives in the include will get parsed

h3. Notes

* If file starts with "/" then file is relative to docroot o/w relative to "page"

