package Pagesmith::HTML::Table;

## Class to render a table;
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

use HTML::Entities qw(encode_entities);
use Date::Format qw(time2str);
use Readonly qw(Readonly);
use POSIX qw(floor);
use URI::Escape qw(uri_escape_utf8);

Readonly my $TIME_FORMAT => '%H:%M';
Readonly my $DATE_FORMAT => '%a, %d %b %Y';
Readonly my $DOFF        => 1_900;
Readonly my $CENT        => 100;
Readonly my $K           => 1_024;
Readonly my $SIZE_R      => 2; ## Numbers up to $K*$SIZE_R are shown in previous size...

sub new {
  my( $class, $r, $options, $columns, $row_data ) = @_;
  $options ||= {};
  my $self = {
    'classes'       => {},
    'options'       => $options || {},
    'columns'       => $columns || [],
    'current_block' => 0,
    '_r'            => $r,
    'blocks'        => [ {
      'class'     => $options->{'block_class'},
      'row_class' => $options->{'row_class'},
      'row_id'    => $options->{'row_id'},
      'data'      => $row_data ? $row_data: [],
    } ],
  };
  bless $self, $class;
  $self->add_classes( $options->{'class'} )
    if exists $options->{'class'};
  $self->add_classes( @{$options->{'classes'}} )
    if exists $options->{'classes'} && ref $options->{'classes'} eq 'ARRAY';

  return $self;
}

sub add_class {
  my( $self, @classes ) = @_;
  $self->add_classes( @classes );
  return $self;
}

sub add_classes {
  my( $self, @classes ) = @_;
  $self->{'classes'}{$_}=1 foreach @classes;
  return $self;
}

sub remove_classes {
  my( $self, @classes ) = @_;
  delete $self->{'classes'}{$_} foreach @classes;
  return $self;
}

sub classes_string {
  my $self = shift;
  my @classes = keys %{$self->{'classes'}};
  my $stripe_class = $self->option( 'sortable' ) ? 'sorted-table' : 'zebra-table';
  push @classes, $stripe_class unless exists $self->{'classes'}{$stripe_class};
  foreach( qw(colfilter filter paginate export) ) {
    my $val = $self->option( $_ );
    push @classes, $_.( $val ? "_$val" : q() ) if defined $val;
  }
  return join q( ), sort @classes;
}

## General option setting...
sub option {
  my( $self, $key ) = @_;
  return $self->{'options'}{$key};
}

sub clear_option {
  my( $self, $key ) = @_;
  delete $self->{'options'}{$key};
  return $self;
}

sub set_option {
  my( $self, $key, $value ) = @_;
  $self->{'options'}{$key} = $value;
  return $self;
}

sub set_pagination {
  my( $self, $sizes, $default ) = @_;
  $default = $sizes->[0] unless defined $default;
  $self->set_option( 'paginate', join q(_), map { $default eq $_ ? "x$_" : $_ } @{$sizes} );
  return $self;
}

sub clear_pagination {
  my $self = shift;
  $self->clear_option( 'paginate' );
  return $self;
}

sub set_filter {
  my $self = shift;
  $self->set_option( 'filter', q() );
  return $self;
}

sub clear_filter {
  my $self = shift;
  $self->clear_option( 'filter' );
  return $self;
}

sub set_colfilter {
  my $self = shift;
  $self->set_option( 'colfilter', q() );
  return $self;
}

sub clear_colfilter {
  my $self = shift;
  $self->clear_option( 'colfilter' );
  return $self;
}

sub set_export {
  my( $self, $formats ) = @_;
  $self->set_option( 'export' , join q(_), map { lc $_ } @{$formats} );
  return $self;
}

sub clear_export {
  my $self = shift;
  $self->clear_option( 'export' );
  return $self;
}

sub make_scrollable {
  my $self = shift;
  return $self->set_option( 'scrollable', 1 );
}

sub make_sortable {
  my( $self, $flag ) = @_;
  $self->add_classes( 'narrow-sorted' ) if defined $flag && $flag eq 'narrow';
  return $self->set_option( 'sortable', 1 );
}

sub set_summary {
  my( $self, $text ) = @_;
  return $self->set_option( 'summary', $text );
}

sub no_header {
  my $self = shift;
  return $self->set_option( 'no-header', 1 );
}

## Handling data...
sub clear_data {
  my $self = shift;
  $self->{'blocks'} = [ { 'class' => q(), 'data' => [] } ];
  return $self;
}

sub add_block {
  my( $self, $class, @row_data ) = @_;
  $self->{'current_block'} = @{ $self->{'blocks'} };
  push @{ $self->{'blocks'} }, { 'class' => $class||q(), 'data' => [ @row_data ? @row_data: () ] };
  return $self;
}

sub set_current_block_class {
  my( $self, $class ) = @_;
  $self->{'blocks'}[ $self->{'current_block'} ]{'class'} = $class;
  return $self;
}
sub set_current_row_class {
  my( $self, $id ) = @_;
  $self->{'blocks'}[ $self->{'current_block'} ]{'row_class'} = $class;
  $self->{'blocks'}[ $self->{'current_block'} ]{'row_id'}    = $id;
  return $self;
}

sub set_current_block {
  my ( $self, $index ) = @_;
  my $len = @{ $self->{'blocks'} };
  if( $index > $len || $index < -$len ) {
    return $self; ## Cannot push past end of block
  }
  if( $index == $len ) {
    $self->add_block();
  } elsif( $index >= 0 ) {
    $self->{'current_block'} = $index;
  } else {
    $self->{'current_block'} = $len - $index;
  }
  return $self;
}

sub add_data {
  my ( $self, @row_data ) = @_;
  push @{ $self->{'blocks'}[ $self->{'current_block'} ]{'data'} }, @row_data;
  return $self;
}

sub blocks {
  my $self = shift;
  return @{ $self->{'blocks'} };
}

## Handling columns...

sub add_columns {
  my( $self, @cols ) = @_;
  foreach my $col ( @cols ) {
    if( exists $col->{'format'} && defined $col->{'format'} && $col->{'format'} =~ m{\A[tfpdzkm]\d*\Z}mxs ) {
      $col->{'align'} ||= 'r';
    }
    if( exists $col->{'format'} && defined $col->{'format'} && $col->{'format'} =~ m{\A([yzkmt]|date|datetime|time).*\Z}mxs ) {
      $col->{'sort_index'} ||= $col->{'key'};
      $col->{'align'}      ||= 'c';
    }
    push @{ $self->{'columns'} }, $col;
  }
  return $self;
}

sub columns {
  my $self = shift;
  return @{ $self->{'columns'} };
}

sub _time_str {
  my( $self, $format, $val ) = @_;
  return q() unless $val;
  return time2str( $format, $val );
}

sub expand_link {
  my( $self, $href_template, $val, $row, $text ) = @_;
  return q() if $text eq q();
  my $url = $self->expand_template( $href_template, $val, $row );
  return $text unless $url;
  my $extra = q();
  if( $url =~ s{\A(.*)\s+}{}mxs ) {
    my %attrs;
    my $attr_values = $1;
    foreach ( split m{\s+}mxs, $attr_values ) {
      if( m{\A(\w+)=(.*)\Z}mxs ) {
        push @{$attrs{$1}}, $2;
      }
    }
    foreach (sort keys %attrs) {
      $extra .= sprintf ' %s="%s"', encode_entities($_), encode_entities( join q( ), sort @{$attrs{$_}} );
    }
  }
  return sprintf '<a %s href="%s">%s</a>', $extra, $url, $text;
}

## no critic (ExcessComplexity)
sub expand_format {
  my( $self, $format, $val ) = @_;
  my $f;
  my $val_defined = defined $val;
  $val = q() unless $val_defined;
  if( ref $format eq 'ARRAY' ) { ## Format can now be an array ref!
    foreach my $format_ref ( @{$format} ) {
      my( $tmp_f, $condition, @condition_pars ) = @{$format_ref};
      next if $condition eq 'defined'   && !$val_defined;
      next if $condition eq 'exact'     && $val ne $condition_pars[0];
      next if $condition eq 'true'      && ! $val;
      next if $condition eq 'contains'  && index $val, $condition_pars[0] < 0;
      next if $condition eq 'lt'        && $val >= $condition_pars[0];
      next if $condition eq 'gt'        && $val <= $condition_pars[0];
      next if $condition eq 'le'        && $val > $condition_pars[0];
      next if $condition eq 'ge'        && $val < $condition_pars[0];
      $f = $tmp_f;
      last;
    }
  } else {
    $f = $format;
  }
  $f ||= 'h';
  return $f eq 'r'                    ?                                                $val         # pass through raw!
       : $f eq 'y'                    ?                                  $val ? 'yes' : 'no'        # render as yes no!
       : $f eq 'h'                    ? encode_entities(                               $val )       # html encode
       : $f eq 'u'                    ? uri_escape_utf8(                               $val )       # url escape
       : $f eq 'hf'                   ? $self->_full_encode(                           $val )       # full html encode
       : $f eq 'uf'                   ? $self->_full_escape(                           $val )       # full url escape
       : $f eq 'email'                ? $self->_safe_email(                            $val )       # <a>email</a>
       : $f =~ m{\Aurl(\d*)\Z}mxs     ? $self->_safe_link(                             $val, $1 )   # <a>url</a>
       : $f eq 'date'                 ? $self->_time_str( $DATE_FORMAT,                $self->munge_date_time( $val ) )
       : $f eq 'datetime'             ? $self->_time_str( "$DATE_FORMAT $TIME_FORMAT", $self->munge_date_time( $val ) )
       : $f eq 'time'                 ? $self->_time_str( $TIME_FORMAT,                $self->munge_date_time( $val ) )
       : $f =~ m{\Adatetime(.+)\Z}mxs ? $self->_time_str( $1,                          $self->munge_date_time( $val ) )
       : $f eq 'currency'             ? sprintf( q(&pound;%0.2f),                      $val )       # &pound;0.00
       : $f eq 't'                    ? $self->commify(                                $val )       # n,nnn,nnn,nnn
       : $f eq 'z'                    ? $self->format_size(                            $val, 0  )   # nnnn K/M/G/...
       : $f =~ m{\Az(\d+)\Z}mxs       ? $self->format_size(                            $val, $1 )   # nnnn.mm K/M/G/...
       : $f eq 'k'                    ? $self->format_fixed(                           $val, 'k', 0 ) # nnnn K
       : $f eq 'm'                    ? $self->format_fixed(                           $val, 'm', 0 ) # nnnn M
       : $f =~ m{\A([k|m])(\d+)\Z}mxs       ? $self->format_fixed(                     $val, $1, $2 ) # nnnn.mm K/M
       : $f =~ m{\At(\d+)\Z}mxs       ? $self->commify( sprintf qq(%0.$1f),            $val )      # n,nnn,nnn,nnn.mm
       : $f =~ m{\Af(\d+)\Z}mxs       ? sprintf( qq(%0.$1f),                           $val )       # Fixed decimal
       : $f =~ m{\Ap(\d+)\Z}mxs       ? sprintf( qq(%0.$1f%%),                         $val*$CENT ) # Percentage
       : $f =~ m{\Ah(\d+)\Z}mxs       ? $self->truncate_string(                        $val, $1   ) # Percentage
       : $f =~ m{\Ad(\d+)\Z}mxs       ?  sprintf( qq(%0$1d),                           $val )       # zero padded
       : $f eq 'd'                    ? sprintf( q(%0d),                               $val )       # Integer
       :                                encode_entities(                               $val )       # HTML safe!
       ;
}

sub truncate_string {
  my( $self, $val, $length ) = @_;
  return length $val > $length
    ? sprintf '<span title="%s">%s...</span>', encode_entities( $val ), encode_entities( substr $val, 0, $length )
    : encode_entities( $val );
}

## use critic

sub format_fixed  {
  my( $self, $size, $unit, $prec ) = @_;
  $prec ||= 0;
  my $sign = $size < 0 ? q(-) : q();
  $size = abs $size;
  $size /= $K;
  $size /= $K unless $unit eq 'k';
  return sprintf "%s%0.${prec}f&nbsp;%s", $sign, $size, uc $unit;
}

sub format_size {
  my( $self, $size, $prec ) = @_;
  $prec ||= 0;
  my $sign = $size < 0 ? q(-) : q();
  $size = abs $size;
  return '0' if $size == 0;
  my $index = floor( log( $size / $SIZE_R ) / log $K );
  return sprintf '%s%d', $sign, $size if $index < 1;
  $size /= $K**$index;
  my @suffix = qw/B K M G T P E Z Y/;

  return sprintf "%s%0.${prec}f&nbsp;%s", $sign, $size, $suffix[ $index ];
}

sub _get_val {
  my( $self, $property, $row ) = @_;
  my $v = ref $row eq 'ARRAY' ? $row->[ $property ]  ## Array ref
        : ref $row eq 'HASH'  ? $row->{ $property }  ## Hash ref
        :                       $row->$property      ## Object ref
        ;
  return $v;
}

sub expand_template {
  my( $self, $template, $val, $row ) = @_;
  my $t;
  if( ref $template eq 'ARRAY' ) {
    foreach my $template_ref ( @{$template} ) {
      my( $tmp_t, $condition, @condition_pars ) = @{$template_ref};
      next if $condition eq 'exact'     && $self->_get_val( $condition_pars[0], $row ) ne $condition_pars[1];
      next if $condition eq 'true'      && ! $self->_get_val( $condition_pars[0], $row );
      next if $condition eq 'contains'  && (index $self->_get_val( $condition_pars[0], $row ), $condition_pars[1] ) < 0;
      $t = $tmp_t;
      last;
    }
  } else {
    $t = $template;
  }
  return unless defined $t;
  $t =~ s{\[\[(.*?):(\w+)\]\]}{$self->expand_format( $1, $self->_get_val( $2, $row ) ) }mxesg;
  return $t;
}

sub format_value {
  my( $self, $val, $col, $row ) = @_;
  my $result = $col->{'template'} ? $self->expand_template( $col->{'template'},    $val, $row )
                                  : $self->expand_format(   $col->{'format'}||'h', $val )
                                  ;
  $result = $self->expand_link( $col->{'link'}, $val, $row, $result ) if $col->{'link'} && $result ne q();
  return '&nbsp;' if !defined $result || $result eq q();
  return $result;
}

sub format_sort {
  my( $self, $val, $col, $row ) = @_;
  my $t;
  if( ref $col->{'sort_index'} eq 'ARRAY' ) {
    my( $tmp_t, $condition, @condition_pars ) = @{$col->{'sort_index'}};
    next if $condition eq 'exact'     && $self->_get_val( $condition_pars[0], $row ) ne $condition_pars[1];
    next if $condition eq 'true'      && ! $self->_get_val( $condition_pars[0], $row );
    next if $condition eq 'contains'  && (index $self->_get_val( $condition_pars[0], $row ), $condition_pars[1] ) < 0;
    $t = $tmp_t;
    last;
  } else {
    $t = $col->{'sort_index'};
  }
  $val = defined $t ? $self->_get_val( $t, $row ) : $val;
  return $col->{'format'} =~ m{\A(date)?(time)?}mxs ? $self->munge_date_time( $val ) : $val;
}

sub extra_value {
  my( $self, $val, $col, $row ) = @_;
  my @class;
  my $extra = q();
  my $al    = $col->{'align'} || q();
  push @class, 'l' if $al eq 'left'   || $al eq 'l';
  push @class, 'r' if $al eq 'right'  || $al eq 'r';
  push @class, 'c' if $al eq 'centre' || $al eq 'center' || $al eq 'c';
  push @class, $col->{'class'} if exists $col->{'class'};
  if( $col->{'sort_index'} ) {
    my $sv = $self->format_sort( $val, $col, $row );
    push @class, sprintf '{sortValue:%f}', $sv||0;# if defined $sv && $sv ne q();
  }
  $extra .= sprintf q( class="%s"), join q( ), @class if @class;
  return $extra;
}

sub other_options {
  my $self = shift;
  return join q(),
         map { $self->option( $_ ) ? sprintf ' %s="%s"', $_, encode_entities( $self->option( $_ ) ) : q() }
         qw(id title);
}

sub render {
  my $self = shift;
  my @html = (
    sprintf q(  <table class="%s" summary="%s"%s>),
      $self->classes_string,
      $self->option( 'summary' )  ? encode_entities( $self->option( 'summary' ) ) : 'Automatically generated table data',
      $self->other_options(),
  );

  unless( $self->option( 'no-header' ) ) {
    push @html, q(    <thead>), q(        <tr>);
    foreach( $self->columns ) {
      if( $_->{'key'} eq q(#) ) {
        push @html, sprintf q(        <th>%s</th>), encode_entities( $_->{'label'}||q(#) );
      } else {
        my $extra_attributes = $_->{'sort_index'} ? q( class="{sorter:'metadata'}") : q();
        $extra_attributes .= sprintf q( style="min-width: %s"), $_->{'min-width'} if exists $_->{'min-width'};
        $extra_attributes .= sprintf q( title="%s"), encode_entities( $_->{'long_label'} ) if exists $_->{'long_label'};
        my $value = encode_entities( exists $_->{'label'} ? $_->{'label'} : $_->{'key'} );
        push @html, sprintf q(        <th%s>%s</th>), $extra_attributes, defined $value ? $value : q();
      }
    }
    push @html, q(      </tr>),q(    </thead>);
  }
  $self->{'row_count'}  = 1;
  push @html, @{ $self->render_block( $_ ) } foreach $self->blocks;
  push @html, q(  </table>);
  if( $self->option('scrollable') ) {
    unshift @html, '<div class="scrollable">';
    push @html, '</div>';
  }
  return join qq(\n), @html;
}

sub render_block {
  my( $self, $block ) = @_;
  # skip block if no data!
  return [] unless @{ $block->{'data'} };
  my @html;
  push @html, $block->{'class'} ? qq(    <tbody class="$block->{'class'}">) : q(    <tbody>);
  foreach my $row ( @{ $block->{'data'} } ) {
    my $row_extra = q();
    my $row_class = $block->{'row_class'} ? $self->expand_template( $block->{'row_class'}, undef, $row ) : q();
    $row_extra .= sprintf ' class="%s"', $row_class if $row_class;
    my $row_id    = $block->{'row_id'}    ? $self->expand_template( $block->{'row_id'},    undef, $row ) : q();
    $row_extra .= sprintf ' id="%s"',    $row_id    if $row_id;
    push @html, qq(      <tr$row_extra>);
    my $c_id = 0;
    foreach my $col ( $self->columns ) {
      my $property = $col->{'key'};
      my( $value, $extra );
      if( $property eq q(#) ) {
        $value = $self->{'row_count'}++;
        $extra = ' class="r"';
      } else {
        my $v = ref $row eq 'ARRAY' ? $row->[$c_id++]
              : ref $row eq 'HASH'  ? $row->{ $col->{'key'} }
              :                       $row->$property;
        $value = $self->format_value( $v, $col, $row );
        $extra = $self->extra_value(  $v, $col, $row );
      }
      push @html, sprintf q(        <td%s>%s</td>), $extra||q(), defined $value ? $value : q();
    }
    push @html, q(      </tr>);
  }
  push @html, q(    </tbody>);
  return \@html;
}

1;
