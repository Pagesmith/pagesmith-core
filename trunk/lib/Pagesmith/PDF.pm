package Pagesmith::PDF;

## PDF generation code...
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

use base qw(Pagesmith::Support);
use PDF::API2;
use PDF::API2::Util qw(page_size);

use Const::Fast qw(const);
const my $DEFAULT_LINEWIDTH  => 0.1;
const my $DEFAULT_SIZE       => 10;
const my $DEFAULT_LINEHEIGHT => 12;
const my $A4_HEIGHT          => 842;
const my $A4_WIDTH           => 595;
const my $DEFAULT_MARGIN     => 40;
const my $LARGE_SIZE         => 12;
const my $DEFAULT_TAB_SIZE   => 0.2;
const my $PERC               => 100;

sub new {
  my( $class, $filename ) = @_;
  my $self = {
    'pdf'            => $filename ? PDF::API2->open($filename) : PDF::API2->new,
    'fonts'          => {},
    'images'         => {},
    'page'           => undef,
    'options' => {
      'stroke_colour'  => 'black',
      'fill_stroke'    => undef,
      'fill_colour'    => 'white',
      'text_colour'    => 'black',
      'stroke_width'   => $DEFAULT_LINEWIDTH,
      'line_height'    => $DEFAULT_LINEHEIGHT,
      'para_spacing'   => $DEFAULT_LINEHEIGHT,
      'align'          => 'l',
      'font'           => 'normal',
      'size'           => $DEFAULT_SIZE,
      'tab_size'       => $DEFAULT_TAB_SIZE,
      'left'           => $DEFAULT_MARGIN,
      'width'          => $A4_WIDTH - 2 * $DEFAULT_MARGIN,
      'header_font'    => [ 'bold',   $LARGE_SIZE ],
      'body_font'      => [ 'normal', $DEFAULT_SIZE ],
      'subhead_font'   => [ 'bold',   $LARGE_SIZE ],
      'header_height'  => undef,
    },
    'file_root'      => undef,
    'default_top'    => $A4_HEIGHT - $DEFAULT_MARGIN,
    'top'            => $A4_HEIGHT - $DEFAULT_MARGIN,
    'debug'          => 0,
    'bleed'          => 5,
    'page_left'      => undef,
    'page_right'     => undef,
    'page_top'       => undef,
    'page_bottom'    => undef,
    'margin_left'    => $DEFAULT_MARGIN,
    'margin_right'   => $DEFAULT_MARGIN,
    'margin_top'     => $DEFAULT_MARGIN,
    'margin_bottom'  => $DEFAULT_MARGIN,
  };
  bless $self, $class;
  return $self
    ->set_corefont( 'normal', 'Helvetica' )
    ->set_corefont( 'bold',   'Helvetica-Bold' )
    ->set_corefont( 'italic', 'Helvetica-Oblique' )
    ->set_paper_size( 'A4' )
    ;
}
sub strike_out {
  my $self = shift;
  return $self
    ->draw_line({ 'stroke_colour' => 'red' }, $self->page_right, $self->page_bottom, $self->page_left, $self->page_top )
    ->draw_line({ 'stroke_colour' => 'red' }, $self->page_right, $self->page_top,    $self->page_left, $self->page_bottom );
}
sub margin_left {
  my $self = shift;
  return $self->{'margin_left'};
}
sub margin_right {
  my $self = shift;
  return $self->{'margin_right'};
}
sub margin_top {
  my $self = shift;
  return $self->{'margin_top'};
}
sub margin_bottom {
  my $self = shift;
  return $self->{'margin_bottom'};
}

sub set_margin_left {
  my( $self, $margin ) = @_;
  $self->{'margin_left'} = $margin;
  return $self;
}
sub set_margin_right {
  my( $self, $margin ) = @_;
  $self->{'margin_right'} = $margin;
  return $self;
}
sub set_margin_top {
  my( $self, $margin ) = @_;
  $self->{'margin_top'} = $margin;
  return $self;
}

sub set_margin_bottom {
  my( $self, $margin ) = @_;
  $self->{'margin_bottom'} = $margin;
  return $self;
}

sub set_margins {
  my( $self, $margin_top, $margin_right, $margin_bottom, $margin_left ) = @_;
  $margin_bottom = defined $margin_bottom ? $margin_bottom : $margin_top;
  $margin_right  = defined $margin_right  ? $margin_right  : $margin_top;
  $margin_left   = defined $margin_left   ? $margin_left   : $margin_right;

  $self->{'margin_top'}    = $margin_top;
  $self->{'margin_bottom'} = $margin_bottom;
  $self->{'margin_left'}   = $margin_left;
  $self->{'margin_right'}  = $margin_right;
  return $self;
}

sub box_left {
  my $self = shift;
  return $self->{'page_left'} + $self->{'margin_left'};
}
sub box_right {
  my $self = shift;
  return $self->{'page_right'} - $self->{'margin_right'};
}
sub box_bottom {
  my $self = shift;
  return $self->{'page_bottom'} + $self->{'margin_bottom'};
}
sub box_top {
  my $self = shift;
  return $self->{'page_top'} - $self->{'margin_top'};
}

sub box_width {
  my $self = shift;
  return $self->page_width - $self->{'margin_left'} - $self->{'margin_right'};
}

sub box_height {
  my $self = shift;
  return $self->page_height - $self->{'margin_top'} - $self->{'margin_bottom'};
}

sub box_center {
  my $self = shift;
  return $self->box_left + $self->box_width / 2;
}

sub vcenter {
  my $self = shift;
  return $self->box_bottom + $self->box_height / 2;
}

sub set_bleed {
  my( $self, $size ) = @_;
  $self->{'bleed'} = $size;
  return $size;
}

sub bleed {
  my $self = shift;
  return $self->{'bleed'};
}
sub bleed_width {
  my $self = shift;
  return $self->page_width + 2 * $self->bleed;
}
sub bleed_right {
  my $self = shift;
  return $self->page_right + $self->bleed;
}
sub bleed_left {
  my $self = shift;
  return $self->page_left - $self->bleed;
}
sub bleed_height {
  my $self = shift;
  return $self->page_height + 2 * $self->bleed;
}

sub bleed_top {
  my $self = shift;
  return $self->page_top + $self->bleed;
}
sub bleed_bottom {
  my $self = shift;
  return $self->page_bottom - $self->bleed;
}

sub page_width {
  my $self = shift;
  return $self->{'page_right'} - $self->{'page_left'};
}
sub page_right {
  my $self = shift;
  return $self->{'page_right'};
}
sub page_left {
  my $self = shift;
  return $self->{'page_left'};
}
sub page_height {
  my $self = shift;
  return $self->{'page_top'} - $self->{'page_bottom'};
}
sub page_top {
  my $self = shift;
  return $self->{'page_top'};
}
sub page_bottom {
  my $self = shift;
  return $self->{'page_bottom'};
}
sub set_paper_size {
  my( $self, @size ) = @_;
  my ($llx, $lly, $urx, $ury) = page_size( @size );
  $self->{'page_left'}   = $llx;
  $self->{'page_bottom'} = $lly;
  $self->{'page_right'}  = $urx;
  $self->{'page_top'}    = $ury;
  $self->pdf->mediabox( $llx, $lly, $urx, $ury );
  return $self;
}

sub debug_on {
  my $self = shift;
  $self->{'debug'}=1;
  return $self;
}

sub debug_off {
  my $self = shift;
  $self->{'debug'}=0;
  return $self;
}

sub debug {
  my $self = shift;
  return $self->{'debug'};
}

sub set_file_root {
  my( $self, $path ) = @_;
  $self->{'file_root'} = $path;
  return $self;
}
sub set_prefs {
  my( $self, $prefs ) = @_;
  $self->pdf->preferences( %{$prefs} );
  return $self;
}
sub add_page {
  my $self = shift;
  $self->{'page'} = $self->pdf->page;
  return $self;
}
sub set_option {
  my( $self, $option, $value ) = @_;
  $self->{'options'}{$option} = $value if exists $self->{'options'}{$option};
  return $self;
}

sub page {
  my $self = shift;
  return $self->{'page'};
}

sub goto_page {
  my( $self, $page_no ) = @_;
  $self->{'page'} = $self->pdf->openpage( $page_no );
  return $self;
}

sub save_as {
  my( $self, $name ) = @_;
  return $self->saveas( $name );
}

sub set_image {
  my( $self, $key, $file, $format ) = @_;
  $format = $file =~ m{[.](\w+)\Z}mxs ? $1 : 'png' unless $format;
  my $method = "image_$format";
  $self->{'images'}{$key} = $self->pdf->$method( $self->{'file_root'}.$file )
    if -e $self->{'file_root'}.$file && $self->pdf->can( $method );
  return $self;
}

sub pdf {
  my $self = shift;
  return $self->{'pdf'};
}

sub gfx {
  my $self = shift;
  return $self->page->gfx;
}

sub txt {
  my $self = shift;
  return $self->page->text;
}

sub font {
  my( $self, $key ) = @_;
  return $self->{'fonts'}{ (exists $self->{'fonts'}{$key} ? $key : 'normal') };
}

sub set_corefont {
  my( $self, $key, $name ) = @_;
  $self->{'fonts'}{$key} = $self->pdf->corefont( $name );
  return $self;
}

sub options {
  my $self = shift;
  return keys %{$self->{'options'}};
}

## no critic (ManyArgs)
sub draw_image {
  my( $self, $key, $x, $y, $w, $h ) = @_;
  $self->gfx->image( $self->{'images'}{$key}, $x, $y, $w, $h )
    if exists $self->{'images'}{$key};
  return $self;
}
## use critic

sub draw_string {
  my( $self, $params, $string ) = @_;
  my $txt = $self->txt;
  foreach ( qw(font size width left align text_colour line_height para_spacing) ) {
    $params->{$_} = $self->{'options'}{$_} unless exists $params->{$_}
  }
  $txt->fillcolor( $params->{'text_colour'} );
  $txt->font( $self->font($params->{'font'}), $params->{'size'} );
  my $top = $params->{'top'}|| $self->{'top'};
  if( exists $params->{'height'} && $params->{'height'} ) { ## We are going to render a box of text...
    ## Ignore what comes out of this...
    $self->text_block( $txt, $string, $params );
  } else {
    if( $params->{'align'} eq 'c' ) {
      $txt->translate( $params->{'left'} + $params->{'width'}/2, $top - $params->{'size'} );
      $txt->text_center( $string );
    } elsif( $params->{'align'} eq 'r' ) {
      $txt->translate( $params->{'left'} + $params->{'width'}, $top - $params->{'size'} );
      $txt->text_right( $string );
    } else {
      $txt->translate( $params->{'left'}, $top - $params->{'size'} );
      $txt->text( $string );
    }
  }
  return $self;
}

## no critic (ManyArgs)
sub draw_box {
  my( $self, $params, $xs,$ys,$w,$h ) = @_;
  my $b = $self->page->gfx;
  ## Copy in defaults...
  foreach ( qw(fill_colour fill_stroke) ) {
    $params->{$_} = $self->{'options'}{$_} unless exists $params->{$_}
  }
  $b->fillcolor(   $params->{'fill_colour'} )   if defined $params->{'fill_colour'};
  $b->strokecolor( $params->{'fill_stroke'} )   if defined $params->{'fill_stroke'};
  $b->move( $xs, $ys );
  $b->line( $xs+$w, $ys );
  $b->line( $xs+$w, $ys+$h );
  $b->line( $xs, $ys+$h );
  $b->close;
  if( defined $params->{'fill_colour'} ) {
    if( defined $params->{'box_stroke'} ) {
      $b->fillstroke;
    } else {
      $b->fill;
    }
  } else {
    $b->stroke;
  }
  return $self;
}
# use critic

## no critic (ExcessComplexity)
sub text_block {
  my( $self, $txt, $string, $params ) = @_;
  # Get the text in paragraphs
  my @paragraphs = split m{\s*\n\s*}mxs, $string;
  # calculate width of all words
  my $ypos = exists $params->{'top'} ? $params->{'top'} : $self->{'top'};
  if( $self->debug ) {
    $self->draw_box( { 'fill_colour' => undef, 'fill_stroke' => 'red' }, $params->{'left'}, $ypos, $params->{'width'}, -$params->{'height'} );
  }
  $txt->fillcolor( $params->{'txt_colour'}||'black' );
  my $space_width = $txt->advancewidth(q( ));
  my @words = split m{\s+}mxs, $string;
  my %width;
  $width{$_} ||= $txt->advancewidth($_) foreach @words;
  my $y_bot = $ypos - $params->{'height'};
  $ypos -=  $params->{'size'};
  my @paragraph = split m{\s+}mxs, shift @paragraphs;
  my $first_line      = 1;
  my $first_paragraph = 1;
  # while we can add another line
  my $endw;
  while ( $ypos >= $y_bot ) {
    unless( @paragraph ) {
      last unless scalar @paragraphs;
      @paragraph = split m{\s+}mxs, shift @paragraphs;
      $ypos -= $params->{'para_spacing'} if $params->{'para_spacing'};
      last if $ypos < $y_bot;
      $first_line      = 1;
      $first_paragraph = 0;
    }
    my $xpos = $params->{'left'};
    # while there's room on the line, add another word
    my @line;
    my $line_width = 0;
    ## no critic (CascadingIfElse)
    if( $first_line && exists $params->{'hanging'} ) {
      my $hang_width = $txt->advancewidth( $params->{'hanging'} );
      $txt->translate( $xpos, $ypos );
      $txt->text( $params->{'hanging'} );
      $xpos       += $hang_width;
      $line_width += $hang_width;
      $params->{'indent'} += $hang_width if $first_paragraph;
    } elsif ( $first_line && exists $params->{'flindent'} ) {
      $xpos       += $params->{'flindent'};
      $line_width += $params->{'flindent'};
    } elsif ( $first_paragraph && exists $params->{'fpindent'} ) {
      $xpos       += $params->{'fpindent'};
      $line_width += $params->{'fpindent'};
    } elsif ( exists $params->{'indent'} ) {
      $xpos       += $params->{'-indent'};
      $line_width += $params->{'-indent'};
    }
    ## use critic
    while ( @paragraph &&
      $line_width + $width{ $paragraph[0] }  + $space_width * scalar @line
       < $params->{'width'}
    ) {
      $line_width += $width{ $paragraph[0] };
      push @line, shift @paragraph;
    }
    # calculate the space width
    my ( $wordspace, $align );
    if( $params->{'align'} eq 'fj' ||
         $params->{'align'} eq 'j' && @paragraph ) {
      @line = split m{}mxs, $line[0] if scalar @line == 1;
      $wordspace = ( $params->{'width'} - $line_width ) / ( scalar @line - 1 );
      $align = 'j';
    } else {
      $align = $params->{'align'} eq 'j' ? 'l' : $params->{'align'};
      $wordspace = $space_width;
    }
    $line_width += $wordspace * ( scalar @line - 1 );
    if ( $align eq 'j' ) {
      foreach my $word (@line) {
        $txt->translate( $xpos, $ypos );
        $txt->text($word);
        $xpos += $width{$word} + $wordspace if @line;
      }
      $endw = $params->{'width'};
    } else {
    # calculate the left hand position of the line
      if ( $align eq 'r' ) {
        $xpos += $params->{'width'} - $line_width;
      } elsif ( $align eq 'c' ) {
        $xpos += $params->{'width'} / 2 - $line_width / 2;
      }
      # render the line
      $txt->translate( $xpos, $ypos );
      $endw = $txt->text( join q( ), @line );
    }
    $ypos -= $params->{'line_height'};
    $first_line = 0;
  }
  unshift @paragraphs, join q( ), @paragraph if scalar @paragraph;

  return {(
    'last_width' => $endw,
    'last_ypos'  => $ypos,
    'overflow'   => join "\n", @paragraphs,
  )};
}
## use critic

## no critic (ManyArgs)
sub draw_line {
  my( $self, $params, $xs, $ys, $xe, $ye ) = @_;
  my $l = $self->page->gfx;
  ## Copy in defaults...
  foreach ( qw(stroke_colour stroke_width fill_colour) ) {
    $params->{$_} = $self->{'options'}{$_} unless exists $params->{$_}
  }

  $l->strokecolor( $params->{'stroke_colour'} ) if defined $params->{'stroke_colour'};
  $l->linewidth(   $params->{'stroke_width'}  ) if defined $params->{'stroke_width'};
  $l->move( $xs, $ys );
  $l->line( $xe, $ye );
  $l->stroke;
  return $self;
}
## use critic

## no critic (ExcessComplexity)
sub draw_table {
  my( $self, $params, $columns, @blocks ) = @_;
  foreach ( qw(header spanning odd even header_font body_font header_height left width) ) {
    $params->{$_} = $self->{'options'}{$_} unless exists $params->{$_}
  }
  my $table_left  = $params->{'left'};
  my $table_width = $params->{'width'};
  my $stars = 0;
  my $fixed = 0;
## Compute cell widths!
  foreach my $col ( @{$columns} ) {
    $col->{'width'}||='1*';
    if( $col->{'width'} =~ m{([\d.]*)[*]}mxs ) {
      $stars += $1||1;
    } elsif( $col->{'width'} =~ m{([\d.]*)%}mxs ) {
      $fixed += $col->{'width'} = $1/$PERC*$table_width;
    } else {
      $fixed += $col->{'width'};
    }
  }
  my $star_width = $stars ? ( $table_width - $fixed ) / $stars : 0;
  foreach my $col ( @{$columns} ) {
    $col->{'width'}||='1*';
    if( $col->{'width'} =~ m{([\d.]*)[*]}mxs ) {
      $col->{'width'} = ($1||1) * $star_width;
    }
  }
  ## Draw heading row!
  $self->draw_box( { 'fill_colour' => $params->{'header'} }, $table_left, $self->{'top'}-$params->{'header_height'}, $table_width, $params->{'header_height'} );
  my $left_pos = $params->{'left'};
  my $padding = 2;
  ## Produce the header row(s)
  foreach my $col ( @{$columns} ) {
    my $hf = $col->{'header_font'} || $params->{'header_font'} || [ 'bold', $DEFAULT_SIZE ];
    $self->draw_string(
      {
        'align'       => 'c',
        'font'        => $hf->[0],
        'size'        => $hf->[1],
        'line_height' => $params->{'header_line_height'} || $hf->[1],
        'left'        => $left_pos+$padding,
        'height'      => $params->{'header_height'}      || undef,
        'width'       => $col->{'width'}-2*$padding,
      },
      $col->{'label'},
    );
    $left_pos += $col->{'width'};
  }
  my $sub_font_f = $params->{'subhead_font'}[0];
  my $sub_font_h = $params->{'subhead_font'}[1];
  my $sub_row_height = $sub_font_h + 2 * $padding;
  my $font_f = $params->{'body_font'}[0];
  my $font_h = $params->{'body_font'}[1];
  $self->down( $params->{'header_height'} );
  foreach my $block ( @blocks ) {
    if( exists $block->{'spanning_header'} ) {
      $self->draw_box( { 'fill_colour' => $params->{'spanning'} }, $table_left, $self->{'top'}-$sub_row_height, $table_width , $sub_row_height);
      $self->draw_string( { 'align' => 'c', 'font' => $sub_font_f, 'size' => $sub_font_h, 'left' => $table_left+$padding, 'width' => $table_width-2*$padding },
        $block->{'spanning_header'} );
      $self->down( $sub_font_h + 2* $padding );
    }
    my $f = 0;
    my $row_height = $font_h + $padding * 2;
    foreach my $row (@{ $block->{'rows'}||[]}) {
      $self->draw_box( { 'fill_colour' => $params->{$f?'even':'odd'} }, $table_left, $self->{'top'}-$row_height, $table_width , $row_height);
      $left_pos = $table_left;
      foreach my $col ( @{$columns} ) {
        $self->draw_string( { 'align' => $col->{'align'}||'l', 'font' => $font_f, 'size' => $font_h, 'left' => $left_pos+$padding, 'width' => $col->{'width'}-2*$padding },
          $row->{$col->{'key'}} );
        $left_pos += $col->{'width'};
      }
      $self->down( $row_height );
      $f = 1- $f;
    }
  }
  return $self;
}
# use critic

sub down {
  my( $self, $height ) = @_;
  $self->{'top'} -= $height;
  return $self;
}

sub draw_twocol {
  my( $self, $params, @rows ) = @_;
  foreach ( qw(font size tab_size line_height) ) {
    $params->{$_} = $self->{'options'}{$_} unless exists $params->{$_}
  }
  foreach( @rows ) {
    $self->draw_string( { 'left' => $self->box_left, 'font' => 'bold', 'size' => $params->{'size'} }, "$_->[0]:" )
         ->draw_string( { 'left' => $self->box_left + $self->box_width * $params->{'tab_size'} , 'size' => $params->{'size'} }, $_->[1] );
    $self->{'top'} -= $params->{'line_height'};
  }
  return $self;
}

1;
