package Pagesmith::Component::Gallery;

## Component to display multiple thumbnails in a single page - with popup viewer
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
Readonly my $DEFAULT_WIDTH       => 100;
Readonly my $DEFAULT_HEIGHT      => 100;
Readonly my $DEFAULT_QUALITY     => 70;
Readonly my $DEFAULT_QUALITY_PNG => 75;
Readonly my $DEFAULT_PADDING     => 5;
Readonly my $DEFAULT_BOX_EXTRA_WIDTH   => 20;
Readonly my $DEFAULT_BOX_EXTRA_HEIGHT  => 80;
Readonly my $SCALE_FACTOR => 3;
Readonly my $BLUR_JPG => 0.5;
Readonly my $BLUR_PNG => 0.25;
Readonly my $BLUR     => 0.1;
Readonly my $ERROR_EXPIRY => -20;

use base qw(Pagesmith::Component::Image);

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use HTML::Entities qw(encode_entities);
use Image::Magick;
use Image::Size qw(imgsize);
use POSIX qw(floor ceil);

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Core qw(safe_md5);

##no critic (ExcessComplexity)
sub define_options {
  my $self = shift;
  return (
    { 'code' => 'raw',            'defn' => q(),  'description' => q(If set do not escape html) },
    { 'code' => 'height',         'defn' => '=i', 'default' => $DEFAULT_HEIGHT  ,  'description' => 'Max height of image to use' },
    { 'code' => 'width',          'defn' => '=i', 'default' => $DEFAULT_WIDTH   ,  'description' => 'Max width of image to use' },
    { 'code' => 'back',           'defn' => '=s', 'default' => 'ffffff'         ,  'description' => 'Background color' },
    { 'code' => 'extn',           'defn' => '=s', 'default' => 'jpg'            ,  'description' => 'Extension for thumbnail jpg/png' },
    { 'code' => 'quality',        'defn' => '=i', 'default' => $DEFAULT_QUALITY ,  'description' => 'Quality of thumbnail (jpg)' },
    { 'code' => 'quality_png',    'defn' => '=i', 'default' => $DEFAULT_QUALITY_PNG ,  'description' => 'Quality of thumbnail (png)' },
    { 'code' => 'padding',        'defn' => '=i', 'default' => $DEFAULT_PADDING ,  'description' => 'Padding around image' },
    { 'code' => 'box_height',     'defn' => '=i', 'default' => $DEFAULT_HEIGHT + $DEFAULT_BOX_EXTRA_HEIGHT ,  'description' => 'Box height' },
    { 'code' => 'box_width',      'defn' => '=i', 'default' => $DEFAULT_WIDTH  + $DEFAULT_BOX_EXTRA_WIDTH  ,  'description' => 'Box width' },
    { 'code' => 'show_captions',  'defn' => q(),  'description' => 'If set show captions' },
    { 'code' => 'columns',        'defn' => '=i', 'description' => 'Number of columns to show' },
    { 'code' => 'align',          'defn' => '=s', 'default' => 'c','description' => 'Alignment of block' },
    { 'code' => 'credit',         'defn' => '=s', 'description' => 'Credit' , 'interleave' => 1 },
    { 'code' => 'link',           'defn' => '=s', 'description' => 'Link', 'interleave' => 1  },
    { 'code' => 'links',          'defn' => q(),  'description' => 'If set show links' },
    { 'code' => 'dir',            'defn' => '=s', 'description' => 'Show all files in given directory' },
  );
}

sub usage {
  return {
    'parameters'  => '{image name}',
    'description' => 'Displays a thumbnail gallery of images (thumbnails are sprited into a large image)',
    'notes'       => [  ],
  };
}

sub interleave_options {
  my $self = shift;
  return qw(credit link);
}

sub execute {
  my $self = shift;
  ## Check file exists....
  my @Q           = $self->pars_hash;
$self->dumper( \@Q );
  my $err         = q();
  my $raw         = $self->option('raw') || 0;
  my $height      = $self->option('height') || $DEFAULT_HEIGHT;
  my $width       = $self->option('width') ||  $DEFAULT_WIDTH;
  my $back        = $self->option('back') || 'ffffff';
  my $out_extn    = $self->option('extn') || 'jpg';
  my @images;
  my $quality_def = $self->option('quality') || $DEFAULT_QUALITY;
  my $quality_png = $self->option('quality_png') || $DEFAULT_QUALITY_PNG;

  my $padding    = $self->option('padding')    || $DEFAULT_PADDING;
  my $height_box = $self->option('box_height') || ( $height + $DEFAULT_BOX_EXTRA_HEIGHT );
  my $width_box  = $self->option('box_width')  || ( $width + $DEFAULT_BOX_EXTRA_WIDTH );
  my $show_captions = $self->option('show_captions') || 0;
  my $cols       = $self->option('columns')    || 0;
  my $caption_alignment = $self->option( 'align' )||'c';
  $quality_png = $quality_def if $quality_png < $quality_def;

  my $image_ref = $self->init_store( 'gallery_images', { 'images' => [] } );

  # Grab initial credit and link parameters...

# If we have -dir flag - grab all images from that folder!

  if ( $self->option('dir') ) {
    ( my $rel_dir = $self->option('dir') ) =~ s{/+\Z}{}mxs;
    unless ( $self->check_file($rel_dir) ) {
      my $dir = $self->filename;
      if ( -d $dir && opendir my $dh, $dir ) {
        while ( my $f = readdir $dh ) {
          next unless -f "$dir/$f" && -e _; ## no critic (Filetest_f)
          next if $f =~ m{[.]html\Z}mxs;
          push @images, { 'img' => "$rel_dir/$f", 'tn' => "$rel_dir/$f", 'caption' => $f };
        }
      }
    }
    ## Really we wanted these in alphabetic order so sort them!
    @images = sort { $a->{'img'} cmp $b->{'img'} } @images;
  }

  # Now loop through parameters;
  while ( my $img_ref = shift @Q ) {
    my $img = $img_ref->{'value'};
    my ( $link, $link_text ) = split m{\s+}mxs, $img_ref->{'link'};
    my $tn = $img =~ s{:(.*)\Z}{}mxs ? $1 : $img;
    my $caption =
      ( @Q && $Q[0] !~ m{\A\S+[.]\w+\Z}mxs && $Q[0] !~ m{\A-}mxs )
      ? shift @Q
      : $img;
    if( $show_captions && !$link_text ) {
      $link_text = q(*);
      $link_text = $caption;
    }
    push @images,
      {
      'link'     => $link,
      'link_txt' => $link_text,
      'img'      => $img,
      'tn'       => $tn,
      'caption'  => $caption,
      'credit'   => $self->credit( $img_ref->{'credit'} ),
    };
  }
  my $key = safe_md5( join q(::), $self->page->full_uri, map( { $_->{'tn'} } @images ), "$height-$width" );
  my $out_filename =  "$key.$out_extn";

  my $ch = Pagesmith::Cache->new( 'tmpfile', 'gallery|' . $out_filename );
  my $img_content = $self->flush_cache( 'thumbnails' ) ? undef : $ch->get;
  if ($img_content) {
    my ( $x, $y, $id ) = imgsize( \$img_content );
    $cols = $x / $width;
  } else {
    my $quality    = $quality_def;
    my $image      = Image::Magick->new();
    my $error_flag = 0;
    my @mapped_images;
    ## Push message....
    foreach (@images) {
      $self->set_filename(q());
      my $file_err = $self->check_file( $_->{'tn'} );
      if($file_err) {
        $error_flag++;
        warn "Unable to find file $_->{'tn'}"; ## no critic (Carping)
        if ( $_->{'tn'} eq $_->{'img'} ) {
          next;
        } else {
          $file_err = $self->check_file( $_->{'img'} );
          if ($file_err) {
            warn "Unable to find file $_->{'img'}"; ## no critic (Carping)
            next;
          }
        }
      }
      my ( $root, $extn ) = $self->filename =~ m{\A(.+)[.](\w+)\Z}mxs;
      unless ($root) {
        $error_flag++;
        warn "Image requires extension: $_->{'img'}/$_->{'tn'}"; ## no critic (Carping)
        next;
      }
      $_->{'file'} = q() . $self->filename;
      $_->{'extn'} = $extn;
      $quality = $quality_png if $extn ne 'jpg';
      push @mapped_images, $_;
    }
    unless (@mapped_images) {
      $self->page->push_message( 'Failed to find any images in list', 'error' );
      return '<p><strong>No images in gallery</strong></p>';
    }
    @images = ();
    my $length_image = 0;
    foreach (@mapped_images) {
      if ( my $T = $image->Read( $_->{'file'} ) ) {
        $error_flag++;
        next;
      }
      foreach( my $x = $length_image; $image->[$x]; $x++ ) { ##no critic (CStyle)
        push @images, $_;
        $length_image++;
      }
    }

# "Die" if we have no images!
    unless (@images) {
      $self->page->push_message( 'Failed to find any valid images in list', 'error' );
      return '<p><strong>No images in gallery</strong></p>';
    }

# Loop through each image and resize!

    foreach ( my $x = 0; $image->[$x]; $x++ ) { ##no critic (CStyle)
      my $extn = $images[$x]{'extn'};
      my $h    = $image->[$x]->get('height');
      my $w    = $image->[$x]->get('width');
      next if $h < $height && $w < $width;
      unless ( $h == $height && $w == $width ) {
        ## Temporarily produce a slightly larger thumbnail
        $image->[$x]->Resize(
          'filter' => 'Triangle',
          'blur'   => $BLUR,
          'size'   => sprintf '%dx%d', $SCALE_FACTOR * $width, $SCALE_FACTOR * $height,
        );
        ## and resize it a bit!
        $image->[$x]->Resize(
          'filter' => $extn eq 'jpg' ? 'Gaussian' : 'Cubic',
          'blur'   => $extn eq 'jpg' ? $BLUR_JPG : $BLUR_PNG,
          'geometry' => sprintf '%dx%d>', $width, $height,
        );
      }
    }

# Compute the size of the thumbnail montage (try to keep it approx square)
# and generate common image!

    $cols ||= ceil( sqrt @images * $height / $width );
    my $rows = ceil( @images / $cols );
    my $t    = $image->Montage(
      'tile'       => $cols . 'x' . $rows,
      'background' => "#$back",
      'geometry'   => sprintf '%dx%d>', $width, $height,
    );
    $t->set( 'quality' => $quality );
    my $tmp_filename = $self->page->tmp_filename($out_extn);
    my $res          = $t->Write($tmp_filename);
    if ($res) {
      $self->page->push_message( "Thumbnail creation error - $tmp_filename - failed Write ($res)", 'error' );
      return;
    }
    if( $out_extn eq 'jpg' ) {
      my $return = system 'jpegoptim', '--strip-all', $tmp_filename;
    } else {
      my $return = system 'optipng', '-o2', '-q', '-preserve', $tmp_filename;
    }
    if( open my $fh, '<', $tmp_filename ) {
      local $INPUT_RECORD_SEPARATOR = undef;
      $img_content = <$fh>;
      close $fh; ## no critic (CheckedSyscalls CheckedClose)
      $ch->set( $img_content, $error_flag ? $ERROR_EXPIRY : 0 );
    }
  }

  my $html    = q();
  my $xoffset = 0;
  my $yoffset = 0;
  my $c       = $cols;
  my $fn      = get_config('TmpUrl') . 'gallery/' . $out_filename;

  push @{ $image_ref->{'images'} }, $fn;
  foreach (@images) {
    my $img_html = sprintf qq(\n  <a href="%s" title="%s%s" class="thickbox" rel="gallery-%s"><img src="/core/gfx/blank.gif" alt="%s" style="padding: 0; margin: %dpx; background:url(%s) no-repeat %dpx %dpx;height:%dpx;width:%dpx;" /></a>),
      encode_entities( $_->{'img'} ), $raw ? $_->{'caption'} : encode_entities( $_->{'caption'} ),
      $_->{'credit'} && $_->{'credit'} ne q(*) ? encode_entities(" [Credit: $_->{'credit'}]") : q(),
      $key,
      encode_entities( $_->{'caption'} ), $padding,
      $fn,
      $xoffset, $yoffset, $height, $width;

    if ( $self->option('links') || $show_captions ) {
      my $lnk = $raw ? $_->{'link_txt'} : encode_entities( $_->{'link_txt'} );
      $lnk = sprintf '<a href="%s" rel="external">%s</a>',encode_entities( $_->{'link'} ), $lnk
        if $_->{'link'} && $_->{'link'} ne q(*);
      $html .= sprintf qq(\n  <div style="text-align:%s; width:%dpx;height:%dpx;border:1px solid #bcc5cc;margin: %dpx; float: left; overflow:hidden">%s<p class="clear">%s</p></div>),
        $caption_alignment,
        $width_box, $height_box, $padding, $img_html, $lnk;
    } else {
      $html .= $img_html;
    }
    $xoffset -= $width;
    $c--;
    unless ($c) {
      $c       = $cols;
      $xoffset = 0;
      $yoffset -= $height;
    }
  }

  return $html;
}
##use critic (ExcessComplexity)

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

