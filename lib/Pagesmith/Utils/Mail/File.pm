package Pagesmith::Utils::Mail::File;

## Base class to add common functionality!
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

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);

use Mime::Base64 qw(encode_base64);
use Digest::MD5 qw(md5_hex);
use Image::Size qw(imgsize);
use Image::Magick;
use WWW::Curl::Easy;
use Pagesmith::ConfigHash qw(proxy_url);

my $_cid = 0;

sub new {
  my $class = shift;
  my $self = {
    'content'   => q(),
    'code'      => q(),
    'filename'  => q(),
    'mime'      => q(),
    'cid'       => q(),
    'encoding'  => q(),
    'width'     => 0,
    'height'    => 0,
    'image'     => 1,
    'inline'    => 'inline',
  };
  bless $self, $class;
  return $self;
}

sub cid {
#@getter
#@self
#@return (String) value of 'cid'

  my $self = shift;
  return $self->{'cid'};
}

sub set_cid {
#@setter
#@self
#@cid (String) value of 'cid'
#@return $self

  my( $self, $cid ) = @_;
  $self->{'cid'} = $cid;
  return $self;
}

sub code {
#@getter
#@self
#@return (String) value of 'code'

  my $self = shift;
  return $self->{'code'};
}

sub set_code {
#@setter
#@self
#@code (String) value of 'code'
#@return $self

  my( $self, $code ) = @_;
  $self->{'code'} = $code;
  return $self;
}

sub content {
#@getter
#@self
#@return (String) value of 'content'

  my $self = shift;
  return $self->{'content'};
}

sub set_content {
#@setter
#@self
#@content (String) value of 'content'
#@return $self

  my( $self, $content ) = @_;
  $self->{'content'} = $content;
  return $self;
}

sub encoding {
#@getter
#@self
#@return (String) value of 'encoding'

  my $self = shift;
  return $self->{'encoding'};
}

sub set_encoding {
#@setter
#@self
#@encoding (String) value of 'encoding'
#@return $self

  my( $self, $encoding ) = @_;
  $self->{'encoding'} = $encoding;
  return $self;
}

sub filename {
#@getter
#@self
#@return (String) value of 'filename'

  my $self = shift;
  return $self->{'filename'};
}

sub set_filename {
#@setter
#@self
#@filename (String) value of 'filename'
#@return $self

  my( $self, $filename ) = @_;
  $self->{'filename'} = $filename;
  return $self;
}

sub height {
#@getter
#@self
#@return (String) value of 'height'

  my $self = shift;
  return $self->{'height'};
}

sub set_height {
#@setter
#@self
#@height (String) value of 'height'
#@return $self

  my( $self, $height ) = @_;
  $self->{'height'} = $height;
  return $self;
}

sub image {
#@getter
#@self
#@return (String) value of 'image'

  my $self = shift;
  return $self->{'image'};
}

sub set_image {
#@setter
#@self
#@image (String) value of 'image'
#@return $self

  my( $self, $image ) = @_;
  $self->{'image'} = $image;
  return $self;
}

sub inline {
#@getter
#@self
#@return (String) value of 'inline'

  my $self = shift;
  return $self->{'inline'};
}

sub set_inline {
#@setter
#@self
#@inline (String) value of 'inline'
#@return $self

  my( $self, $inline ) = @_;
  $self->{'inline'} = $inline;
  return $self;
}

sub mime {
#@getter
#@self
#@return (String) value of 'mime'

  my $self = shift;
  return $self->{'mime'};
}

sub set_mime {
#@setter
#@self
#@mime (String) value of 'mime'
#@return $self

  my( $self, $mime ) = @_;
  $self->{'mime'} = $mime;
  return $self;
}

sub width {
#@getter
#@self
#@return (String) value of 'width'

  my $self = shift;
  return $self->{'width'};
}

sub set_width {
#@setter
#@self
#@width (String) value of 'width'
#@return $self

  my( $self, $width ) = @_;
  $self->{'width'} = $width;
  return $self;
}


sub render {
  my $self = shift;
  my $render = q();
  if( $self->image ) {
    $render .= sprintf 'Content-Type: %s;', $self->mime;
  } else {
    $render .= sprintf
      "Content-Disposition: attachment\r\nContent-Type: %s; name= %s\r\n",
      $self->mime, $self->code;
    if( $self->encoding ) {
      $render .= sprintf "Content-Encoding: %s\r\n", $self->encoding;
    }
  }
  $render .= sprintf
    "Content-ID: %s\r\nContent-Transfer-Encoding: base64\r\n\r\n%s",
    $self->cid,
    encode_base64( $self->content );
  return $render;
}

sub load_from_string {
  my( $self, $code, $string, $mime_type );
  $mime_type ||= 'text/plain';
  $self->set_content(  $string );
  $self->set_code(     $code );
  $self->set_filename( $code =~ m{([^\s/]+)\Z}msx ? $1 : $code );
  $self->set_cid(      md5_hex( $_cid++ ) );
  $self->set_mime(     $mime_type;
  return unless $mime_type =~ m{\Aimage/(.*)\Z}msx ) && !$self->width;

  my $image = Image::Magick->new( $1 );
  $image->BlobToImage( $string );
  return unless $image->get('width');
  $self->set_width(  $image->get( 'width'  ) );
  $self->set_height( $image->get( 'height' ) );
  $self->set_image(  1 );
  return;
}

sub load_from_file {
  my( $self, $file, $code, $mime_type ) = @_;
  $mime_type ||= q();
  $code      = $file unless $code;
  return 0 unless -e $file && -r $file && -f $file; ## no critic (Filetest_f)
  if( open my $fh, q(<), $file ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $img_content = <$fh>;
    close $fh; ## no critic (CheckedSyscalls CheckedClose)
    my( $x, $y, $type ) = imgsize( $file );
    return unless $x;
    $self->set_width(  $x );
    $self->set_height( $y );
    $mime_type ||= 'image/'.lc $type;
    return $self->load_from_string( $code, $string, $mime_type );
  }
  return;
}

sub load_from_url {
  my( $self, $url, $doc_root, $mime_type ) = @_;
  $doc_root ||= q();
  $mime_type ||= q();
  if( $url =~ m{\Ahttps?://}msx ) {
    ## Do a curl fetch here!
    my $curl = WWW::Curl::Easy->new;
## no critic (CallsToUndeclaredSubs)
    $curl->setopt( CURLOPT_URL, $url );
    $curl->setopt( CURLOPT_HEADER, 0 );
    $curl->setopt( CURLOPT_RETURNTRANSFER, 1 );
    my( $host, $port ) = split m{:}mxs, proxy_url();
    $self->setopt( CURLOPT_PROXY,     $host );
    $self->setopt( CURLOPT_PROXYPORT, $port );
    my $content;
    $curl->setopt(CURLOPT_WRITEDATA,\$content);
    my $ret = $curl->perform;
## use critic;
    return unless $content;
    return $self->load_from_string( $url, $content, $mime_type );
  }
  $doc_root ||= q();#;$GLOBALS['DOCUMENT_ROOT'];

  return $self->load_from_file( $doc_root.$url, $url, $mime_type );
}

1;
