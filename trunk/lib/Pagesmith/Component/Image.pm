package Pagesmith::Component::Image;

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

use Readonly qw(Readonly);
Readonly my $MAX_SIZE_TO_SCALE   => 1000;
Readonly my $DEFAULT_WIDTH       => 100;
Readonly my $DEFAULT_HEIGHT      => 100;
Readonly my $DEFAULT_QUALITY     => 65;
Readonly my $DEFAULT_QUALITY_PNG => 75;
Readonly my $DEFAULT_PADDING     => 10;
Readonly my $DEFAULT_BOX_WIDTH   => 240;
Readonly my $DEFAULT_BOX_EXTRA_WIDTH   => 20;
Readonly my $DEFAULT_BOX_EXTRA_HEIGHT  => 80;
Readonly my $SCALE_FACTOR => 3;
Readonly my $BLUR_JPG => 0.5;
Readonly my $BLUR_PNG => 0.25;
Readonly my $BLUR     => 0.1;
Readonly my $ERROR_EXPIRY => -20;
Readonly my $LINK_SIZE => 40;

use base qw(Pagesmith::Component::File);

use Carp qw(carp);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use HTML::Entities qw(encode_entities);
use Image::Size qw(imgsize);
use Image::Magick;

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Core qw(safe_md5);

my %credits = (
  'grl'                                 => 'Genome Research Limited',
  'wtsi'                                => 'Genome Research Limited',
  'The Wellcome Trust Sanger Institute' => 'Genome Research Limited',
  'Wellcome Trust Sanger Institute'     => 'Genome Research Limited',
  'wl'                                  => 'Wellcome Library, London',
);

sub credit {
  my( $self, $credit ) = @_;
  #return q() unless $credit;
  $credit ||= 'wtsi';
  return $credits{$credit}||$credit;
}

sub define_options {
  my $self = shift;

  return (
    $self->SUPER::define_options,
    { 'code' => 'quality',        'defn' => '=i', 'default' => $DEFAULT_QUALITY ,  'description' => 'Quality of thumbnail (jpg)' },
    { 'code' => 'left',           'defn' => q(),  'description' => 'Float left' },
    { 'code' => 'right',          'defn' => q(),  'description' => 'Float right' },
    { 'code' => 'center',         'defn' => q(),  'description' => 'Centre align' },
    { 'code' => 'short',          'defn' => '=s',  'description' => 'Short caption' },
    { 'code' => 'noshort',        'defn' => q(),   'description' => q(Don't display short caption) },
    { 'code' => 'credit',         'defn' => '=s',  'description' => 'Credit' },
    { 'code' => 'nocredit',       'defn' => q(),   'description' => q(Don't display credit) },
    { 'code' => 'nozoom',         'defn' => q(),   'description' => q(Don't display zoom link) },
    { 'code' => 'boxpadding',     'defn' => '=i', 'default' => $DEFAULT_PADDING ,  'description' => 'Padding around image' },
    { 'code' => 'boxwidth',       'defn' => '=i', 'default' => 0 ,  'description' => 'Box width' },
    { 'code' => 'height',         'defn' => '=i', 'default' => 0  ,  'description' => 'Max height of image to use' },
    { 'code' => 'width',          'defn' => '=i', 'default' => 0   ,  'description' => 'Max width of image to use' },
    { 'code' => 'w',              'defn' => '=i', 'default' => 0  ,  'description' => 'Alternative to height' },
    { 'code' => 'h',              'defn' => '=i', 'default' => 0   ,  'description' => 'Alternative to width' },
    { 'code' => 'tn',             'defn' => '=s', 'description' => 'Thumbnail image over-ride name' },
    { 'code' => 'clear',          'defn' => q(),  'description' => q(If set add clear style so doesn't break float pattern) },
  );
}

sub usage {
  return {
    'parameters'  => '{image name}',
    'description' => 'Displays a thumnail image in a floating/centered box with a link to a popup zoom window...',
    'notes'       => [  ],
  };
}

##no critic (ExcessComplexity)
sub _thumbnail {
## Create a thumbnail image with the given dimensions and
## store it in the appropriate location.....
  my ( $self, $in_filename, $width, $height ) = @_;
  ## Read the file with image Magick...

  my ($extn) = $in_filename =~ m{[.](\w+)\Z}mxs;
  $extn = $extn =~ m{^jp(?:eg|[eg])\Z}mxs ? 'jpg' : 'png';
  my $image = Image::Magick->new();
  ## Couldn't read file
  my $res = $image->Read($in_filename);
  if ($res) {
    carp "Thumbnail creation error - $in_filename - failed Read ($res)";
    return;
  }

  if ( $height || $width ) {
    ## If the image is small we expand it a bit then resample it
    ## this can lead to better thumbnail quality!
    if ( $width < $MAX_SIZE_TO_SCALE && $height < $MAX_SIZE_TO_SCALE ) {
      $image->Resize(
        'filter' => 'Triangle',
        'blur'   => $BLUR,
        'size'   => $width && $height ? sprintf '%dx%d', $SCALE_FACTOR * $width, $SCALE_FACTOR * $height
        : $width ? sprintf '%d', $SCALE_FACTOR * $width
        : sprintf 'x%d', $SCALE_FACTOR * $height,
      );
    }

    ## Now resize it to the thumbnail size that we want!
    ## Different options for jpeg && png/gif
    $image->Resize(
      'filter' => $extn eq 'jpg' ? 'Gaussian' : 'Cubic',
      'blur'   => $extn eq 'jpg' ? $BLUR_JPG  : $BLUR_PNG,
      'geometry' => $width && $height ? sprintf '%dx%d>', $width, $height
                  : $width            ? sprintf '%d>', $width
                  :                     sprintf 'x%d>', $height,
    );
    $image->set( 'quality' => $self->option('quality') || $DEFAULT_QUALITY ) if $extn eq 'jpg';

  }
  ## Finally right out the image to disk - but only temporarily so we can
  ## apply jpegoptim or optipng to it!
  my $tmp_filename = $self->page->tmp_filename($extn);
  $res = $image->Write($tmp_filename);
  if ($res) {
    carp "Thumbnail creation error - $tmp_filename - failed Write ($res)";
    return;
  }

  ## Now we optimise the image using jpegoptim or optipng depending
  ## on type... Note that .gif images get optimised to .png images
  ## these remove quite a bit of **** and make the output files
  ## smaller - allowing slightly higher quality jpegs etc... with much
  ## smaller file size...
  if( $extn eq 'jpg' ) {
      my $return = system 'jpegoptim', '--strip-all', $tmp_filename;
    } else {
      my $return = system 'optipng', '-o2', '-q', '-preserve', $tmp_filename;
    }
  return unless open my $fh, '<', $tmp_filename;
  local $INPUT_RECORD_SEPARATOR = undef;
  my $img = <$fh>;
  close $fh; ##no critic (CheckedSyscalls CheckedClose)
  unlink $tmp_filename;
  return $img;
}
##use critic (ExcessComplexity)

sub my_cache_key {
  my $self = shift;
  return $self->checksum_parameters();
}

##no critic (ExcessComplexity)
sub execute {
  my $self = shift;
  ## Check file exists....
  my @Q   = $self->pars;
  my $url = encode_entities( shift @Q );
  my $err = $self->check_file($url);

  return $err if $err;

  my ( $root, $extn ) = $self->filename =~ m{^(.+)[.](\w+)\Z}mxs;
  return $self->error('Image requires extension') unless $root;
  my ( $img_x, $img_y ) = imgsize( $self->filename );
  my ( $orig_img_x, $orig_img_y ) = ( $img_x, $img_y );
  return $self->error('Malformed image') unless $img_x;

  my $side =
      $self->option('left')   ? 'left'
    : $self->option('right')  ? 'right'
    : $self->option('center') ? 'center'
    :                           'left';
  my $caption = "@Q";
  $caption =~ s{\s+}{ }mxgs;
  my $short = $self->option('short') || $caption;
  $short =~ s{\s+}{ }mxgs;
  $short = q() if $self->option('noshort');
  my $credit = $self->option('credit') || q();
  $credit = q() if $self->option('nocredit');

  my $credit_marked_up = q();
  if ($credit) {
    $credit = $credits{$credit} if exists $credits{$credit};
    if( $credit =~ m{\Ahttps?://\S+$}mxs ) {
      $credit_marked_up = "\n[". $self->safe_link( $credit, $LINK_SIZE ).q(]);
    }
    $credit = "\n[" . encode_entities($credit) . q(]);
    $credit_marked_up ||= $credit;
  }

  ## Get size of the thumbnail from the options...

  my $box_width = $self->option('boxwidth') || $DEFAULT_BOX_WIDTH;
  my $padding   = $self->option('padding')  || $DEFAULT_PADDING;
  my $inner_width = $box_width - 2 * $padding;
  my $width = $self->option('width') || $self->option('w') || $inner_width;
  my $height = $self->option('height') || $self->option('h') || 0;

  my $thumb_url;
  if( $self->option('tn') ) {
    my $t_file = $self->filename;
    unless( $self->check_file( $self->option('tn'), 1 ) ) {
      my( $t_width, $t_height ) = imgsize( $self->filename );
      if( $t_width && $t_height ) {
        $thumb_url = encode_entities( $self->option('tn') );
        $width     = $t_width;
        $height    = $t_height;
      }
    }
    $self->set_filename( $t_file );
  }

  $inner_width = $width;
  $box_width   = $width + 2 * $padding;

  my $class = $side eq 'center' ? 'cPic-c' : "cPic $side";
     $class.= ' clear' if $self->option('clear');
  my $style = $side eq 'center' ? q() : sprintf ' style="width:%dpx"', $box_width;
  if ( $img_x <= $width && ( !$height || $img_y <= $height ) ) {
    $thumb_url ||= $url;
    ## Actual image is smaller than the size of the thumbnail box
    ## so we don't have to thumbnail it!
    my $html = sprintf q(<div class="%s"%s><img src="%s" style="width:%dpx;height:%dpx;" alt="%s" />),
      $class, $style, $thumb_url, $img_x, $img_y, encode_entities($short);
    $html .= sprintf q(<p style="width:%dpx">%s%s</p>), $inner_width, encode_entities($caption), $credit if $caption || $credit;
    return qq($html</div>);
  }
  ## We need to thumbnail the image....
  ## First generate the temporary filename!!!
  if( !$thumb_url ) {
    $thumb_url = $url;    ##
    $extn = 'png' if $extn eq 'gif';
    my $qual = $self->option('quality') || $DEFAULT_QUALITY;
    my $tn          = safe_md5( "$root.$height-$width-" . $qual ) . ".$extn";
    my $ch          = Pagesmith::Cache->new( 'tmpfile', "img|$tn" );
    my $img_content = $self->flush_cache('thumbnails') ? undef : $ch->get;
    unless( $img_content ) {
      $img_content = $self->_thumbnail( $self->filename, $width, $height );
      $ch->set($img_content);
    }
    if ($img_content) {
      ( $width, $height ) = imgsize( \$img_content );
      $thumb_url = get_config('TmpUrl') . 'img/' . $tn;
    } else {
      if ( $height && $img_y > $height ) {
        $img_x *= int $height / $img_y;
        $img_y = $height;
      }
      if ( $img_x > $width ) {
        $img_y *= int $width / $img_x;
        $img_x = $width;
      }
      ( $width, $height ) = ( $img_x, $img_y );
    }
  }
  if ( $self->option('nozoom') ) {
    my $html = sprintf q(<div class="%s"%s><img src="%s" style="width:%dpx;height:%dpx;" alt="%s" />),
      $class, $style, $thumb_url, $width, $height, encode_entities($short);
    $html .= sprintf q(<p style="width:%dpx">%s%s</p>), $inner_width, encode_entities($caption), $credit if $caption || $credit;
    return qq($html</div>);
  }
  my $zoom = sprintf q(<a href="%s" class="thickbox" title="%s%s">), $url, encode_entities($caption), $credit;
  my $html = sprintf q(<div class="%s"%s>%s<img src="%s" style="width:%dpx;height:%dpx;" alt="%s" /></a>),
    $class, $style, $zoom, $thumb_url, $width, $height, encode_entities($short);
  if ( $short || $credit ) {
    $html .= sprintf q(<p style="width:%dpx">%s%s<br />%s<img src="/core/gfx/blank.gif" alt="Enlarge this image (%d x %d)" /></a></p>),
      $inner_width, encode_entities($short), $credit_marked_up, $zoom, $orig_img_x, $orig_img_y;
  } else {
    $html .= sprintf q(<p style="border-top:0;width:%dpx">%s<img src="/core/gfx/blank.gif" alt="Enlarge this image (%d x %d)" /></a></p>),
      $inner_width, $zoom, $orig_img_x, $orig_img_y;
  }
  return qq($html</div>);
}
##use critic (ExcessComplexity)
1;

__END__

h3. Sytnax

<% Image
  -boxwidth=i?
  -(center|left|right)?
  -clear?
  -credit=s?
  -(height|h)=i?
  -nocredit?
  -noshort?
  -nozoom?
  -padding=i?
  -quality=d
  -short=s?
  -(width|w)=i?

  url
  caption
%>

h3. Purpose

Embed a captioned image into the webpage - resized to fit the page - with a
zoom link to the original image

h3. Options

* boxwidth (opt default=240) - Width in pixels of box containing image

* center/left/right (opt default=left) - position of image in page - either
  floated left, right, or central to the page.

* clear (opt default off) - Put a clear break in the image - so that it is not affected
  by previous floated images

* credit (opt default=wtsi) - Credit to appear under image, there are three shortenings:
  * grl & wtsi - give a credit of "Genome Research Limited"
  * wl         - gives a credit of "Wellcome Library, London"

* height/h (opt default=100) - maximum height of thumbnail image

* nocredit (opt default off) - don't include a credit on the image

* noshort (opt default off) - don't include the short caption on the image

* nozoom (opt default off) - don't include a zoom link even if image is rescaled

* padding (opt default=10) - width of whitespace around image

* quality (opt default=65 for jpg, 75 for png) - Quality of thumbnail image

* short (opt) - Shortened caption for the image

* width/w (opt default=220) - maximum width of thumbnail image - defaults to 240-10 = 220

h3. Notes

* Thumbnail is dynamically generated

h3. See Also

* Directive: FacultyImage, FeatureImage

h3. Examples

* <% Image gfx/my_image.png This is a test image %>

h3. Developer notes

