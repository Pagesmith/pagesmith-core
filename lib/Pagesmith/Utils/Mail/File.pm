package Pagesmith::Utils::Mail::File;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2012, 2013, 2014 Genome Research Ltd.
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

use Const::Fast qw(const);
const my %IMG_TYPES => map { ($_=>1) } qw( PNG JPG GIF BMP TIF JPEG TIFF );
use MIME::Base64 qw(encode_base64);
use Digest::MD5 qw(md5_hex);
use Image::Size qw(imgsize);
use Image::Magick;
use Pagesmith::Utils::Curl::Fetcher;
use Pagesmith::ConfigHash qw(proxy_url docroot);

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
    'type'      => 'inline',
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

sub type {
#@getter
#@self
#@return (String) value of 'type'

  my $self = shift;
  return $self->{'type'};
}

sub set_type {
#@setter
#@self
#@inline (String) value of 'type'
#@return $self

  my( $self, $type ) = @_;
  $self->{'type'} = $type;
  return $self;
}

sub make_inline {
  my $self = shift;
  $self->{'type'} = 'inline';
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
  my ( $self, $type ) = @_;
  return sprintf qq(Content-Type: %s; name="%s"\r\nContent-Transfer-Encoding: base64\r\nContent-ID: <%s>\r\nContent-Disposition: inline; filename="%s"\r\n\r\n%s),
    $self->mime, $self->filename, $self->cid, $self->filename, encode_base64($self->content) if $type eq 'image';
  return sprintf qq(Content-Type: %s; name="%s"\r\nContent-Transfer-Encoding: base64\r\nContent-Disposition: attachment; filename="%s"\r\n\r\n%s),
    $self->mime, $self->filename, $self->filename, encode_base64($self->content);
}

sub load_from_string {
#@params ($self, string $code, string $string, string $type)
#@return
  my( $self, $code, $string, $mime_type ) = @_;
  $mime_type ||= 'text/plain';
  $self->set_content(  $string );
  $self->set_code(     $code );
  $self->set_filename( $code =~ m{([^\s/]+)\Z}msx ? $1 : $code );
  $self->set_cid(      md5_hex( $_cid++ ) );
  $self->set_mime(     $mime_type );
  ## For images we add additional information about them being an image!
  return 1 unless $mime_type =~ m{\Aimage/(.*)\Z}msx;

  ## Load image with Image::Magick to get it's details...!
  my $image = Image::Magick->new( $1 );
  $image->BlobToImage( $string );
  return 1 unless $image->get('width');
  $self->set_width(  $image->get( 'width'  ) );
  $self->set_height( $image->get( 'height' ) );
  $self->set_image(  1 );
  return 1;
}

sub load_from_file {
  my( $self, $code, $file, $mime_type ) = @_;
  $mime_type ||= q();
  $code      = $file unless $code;
  return 0 unless -e $file && -r $file && -f $file; ## no critic (Filetest_f)
  if( open my $fh, q(<), $file ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $contents = <$fh>;
    close $fh; ## no critic (CheckedSyscalls CheckedClose)
    unless( $mime_type ) { ## If no mime-type set see if we have an image!
      my( $x, $y, $type ) = imgsize( $file );
      my $k = uc $type;
      if( $x && $y && exists $IMG_TYPES{ $k }) {
        $self->set_width(  $x );
        $self->set_height( $y );
        $mime_type ||= 'image/'.lc $type;
      } else {
        $mime_type = 'application/octet-stream';
      }
    }
    return $self->load_from_string( $code, $contents, $mime_type );
  }
  return 0;
}

sub load_from_url {
  my( $self, $url, $mime_type ) = @_;
  $mime_type ||= q();
  unless( $url =~ m{\Ahttps?://}msx ) { ## This is a relative URL!
    return $self->load_from_file( $url, docroot.$url, $mime_type );
  }
  ## Do a curl fetch here!
  ## We could optimise this in the future (by storing the location
  ## in this object - and pushing the fetch up a level (or to be
  ## cheeky and initialise objects here and run the fetcher loop
  ## ##VERY SCARY!## to push this up a level.. and so parallize fetching...
  my $c        = Pagesmith::Utils::Curl::Fetcher->new;
  my $req      = $c->new_request( $url );
  my $contents = q();
  while( $c->has_active ) {
    if( $c->active_transfers == $c->active_handles ) {
      $c->short_sleep;
      next;
    }
    ## We know we only have one request!
    my $r = $c->next_request;
    $c->remove( $r );
    $contents = $r->response->body if $r->response->{'success'};
  }
  return 0 unless $contents;
  return $self->load_from_string( $url, $contents, $mime_type );
}

1;
