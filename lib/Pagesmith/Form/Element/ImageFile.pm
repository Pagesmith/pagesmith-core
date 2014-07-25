package Pagesmith::Form::Element::ImageFile;

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

use Image::Size qw(imgsize);
use Image::Magick;
use Const::Fast qw(const);
use HTML::Entities qw(encode_entities);
use MIME::Base64 qw(encode_base64);
const my $OPTIMIZE             => 1;
const my $BLUR_JPG             => 0.5;
const my $BLUR_PNG             => 0.25;
const my $DEFAULT_QUALITY      => 65;
const my $DEFAULT_QUALITY_PNG  => 75;
const my $K                    => 1024;
const my $DEFAULT_GEOMETRY     => '180x120>';

my %viewable_bitmap = map { ($_=>1) } qw(png gif jpg);

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);

use base qw( Pagesmith::Form::Element::File );
use Pagesmith::Cache;

sub set_geometry {
  my ($self, $geo) = @_;
  my $self->{'geometry'} = $geo;
  return $self;
}

sub geometry {
  my $self = shift;
  return exists $self->{'geometry'} ? $self->{'geometry'} : $DEFAULT_GEOMETRY;
}

sub new {
  my($class,$section,$pars) = @_;
  my $self = $class->SUPER::new( $section, $pars );
  $self->{'allow_vector'} = exists $pars->{'allow_vector'} ? 1 : 0;
  return $self;
}

sub set_allow_vector {
  my $self = shift;
  $self->{'allow_vector'} = 1;
  return $self;
}

sub set_disallow_vector {
  my $self = shift;
  $self->{'allow_vector'} = 0;
  return $self;
}

sub allow_vector {
  my $self = shift;
  return $self->{'allow_vector'};
}

sub remove_uploaded_file {
  my( $self, $key ) = @_;
  $self->SUPER::remove_uploaded_file( $key );
  return 1;
}

sub extra_file_info {
  my($self,$upload, $content ) = @_;
  my ($w, $h, $type) = imgsize( $content );
  my $image;
  ## We need to look to see if this is a pdf!
  unless( $w ) {
    if(
      $self->allow_vector && (
      $upload->type =~ m{\Aimage/}mxs ||
      $upload->type =~ m{\Aapplication/(postscript|pdf)\Z}mxs
    )) {
      $image = Image::Magick->new;
      $image->Set('alpha'=>'remove');
      $image->BlobToImage( ${$content} );
      return ( 'error' => 'not an image' ) unless $image->[0];
      $image = $image->[0];
      $w = $image->Get('width');
      $h = $image->Get('height');
      $type = $self->get_extn_from_type( $upload->type );
    } else {
      return ( 'error' => 'not an image' );
    }
  }

  ## Create thumbnail....
  unless( $image ) {
    $image = Image::Magick->new( 'magick' => lc $type );
    $image->BlobToImage( ${$content} );
    return ( 'error' => 'not an image' ) unless $image;
  }
  my $extn = $type eq 'JPG' ? 'jpg' : 'png';

  $image->Resize(
    'filter'   => $extn eq 'jpg' ? 'Gaussian' : 'Cubic',
    'blur'     => $extn eq 'jpg' ? $BLUR_JPG  : $BLUR_PNG,
    'geometry' => $self->geometry,
  );
  $image->set( $extn eq 'jpg' ? $DEFAULT_QUALITY : $DEFAULT_QUALITY_PNG );

  my $img;
  if( $OPTIMIZE ) {
    my $tmp_filename = $self->tmp_filename($extn);
    my $res = $image->Write($tmp_filename);
    if( $extn eq 'jpg' ) {
      my $return = system 'jpegoptim', '--strip-all', $tmp_filename;
    } else {
      my $return = system 'optipng', '-o2', '-q', '-preserve', $tmp_filename;
    }
    if( open my $fh, '<', $tmp_filename ) {
      local $INPUT_RECORD_SEPARATOR = undef;
      $img = <$fh>;
      close $fh; ## no critic (RequireChecked)
    }
    unlink $tmp_filename;
  } else {
    $img= $image->ImageToBlob;
  }
  if( $img ) {
    return (
      'xtn'         => lc( $type ),
      'dimensions'  => "$w x $h",
      'tn_mime'     => qq(image/$extn),
      'tn_blob'     => encode_base64($img),
      'tn_width'    => $image->Get('width'),
      'tn_height'   => $image->Get('height'),
    );
  }
  return ( 'dimensions'     => "$w x $h" );
}

sub render_single {
  my($self,$flag) = @_;
  ## Get first value....
  my ($entry) = values %{$self->{'user_data'}[0]{'files'}||{}};
  return '<p>No image currently attached</p>' unless $entry;
  my $prefix = $self->form_config->option('code').q(/).$self->code;
  ## no critic (ImplicitNewlines)
  my $class = exists $viewable_bitmap{$entry->{'xtn'}} ? q( class="thickbox") : q( rel="external");
  return sprintf '
  <div class="file-blob"><a%s href="/action/FormFile/%s/%d/%s-%d.%s"><img src="/action/FormFile/%s/%d/tn" style="height:%dpx;width:%dpx" alt="thumbnail of %s"/></a></div>
  <div class="file-details file-image">
  <dl class="twocol">
    <dt>Name</dt><dd>%s</dd>
    <dt>Dimensions</dt><dd>%s</dd>
    <dt>Size</dt><dd>%0.1fk</dd>
    <dt>Type</dt><dd>%s</dd>
    %s
  </dl>
  </div>',
    $class,
    $prefix, $entry->{'ndx'}, $prefix, $entry->{'ndx'},$entry->{'xtn'},
    $prefix, $entry->{'ndx'},
    $entry->{'tn_height'}, $entry->{'tn_width'},
    encode_entities( $entry->{'name'} ),

    encode_entities( $entry->{'name'} ),
    $entry->{'dimensions'},
    $entry->{'size'}/$K,
    encode_entities($entry->{'type'}),
    !$flag ? q() : sprintf '<dt>Delete?</dt><dd><input type="checkbox" class="checkbox _cb_%s" id="%s_del_%d" name="%s_del_%d" value="delete" /></dd>',
      $self->code, $self->generate_id_string,  $entry->{'ndx'}, $self->code, $entry->{'ndx'};
  ## use critic
}

sub extra_columns {
  my $self = shift;
  my $prefix = $self->form_config->option('code').q(/).$self->code;
  return (
    { 'key' => 'dimensions', 'label' => 'Dimensions', 'align' => 'center', },
    { 'key' => 'thumbnails', 'label' => 'Thumbnail', 'align' => 'center', 'template' => [
      [ qq(<span><a class="thickbox" href="/action/FormFile/$prefix/[[h:ndx]]/$prefix-[[h:ndx]].[[h:xtn]]"><img src="/action/FormFile/$prefix/[[h:ndx]]/tn" style="height:[[h:tn_height]]px;width:[[h:tn_width]]px" alt="Thumbnail of [[h:name]]" /></a></span>),
        'true', 'tn_width' ],
      [ q(--), 'any' ],
    ] },
  );
}

1;
