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
use Const::Fast qw(const);
use Scalar::Util qw(blessed);
use URI::Escape qw(uri_escape_utf8);

const my $TIME_FORMAT => '%H:%M';
const my $DATE_FORMAT => '%a, %d %b %Y';
const my $DOFF        => 1_900;
const my $CENT        => 100;

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
      'spanning'  => 0,
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
  my $count = $self->option('count');
  my $url   = $self->option('refresh_url');
  my $x_url = $self->option('export_url');
  my %meta_data;
  if( defined $url && defined $count ) {
    $meta_data{'refresh'} = $url;
    $meta_data{'entries'} = $count;
    $meta_data{'export'}  = $x_url if defined $x_url;
  }

  push @classes, encode_entities( $self->json_encode( \%meta_data ) ) if keys %meta_data;

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
  my( $self, $key, @values ) = @_;
  my $value = @values ? $values[0] : $key;
  $self->{'options'}{$key} = $value;
  return $self;
}

sub set_pagination {
  my( $self, $sizes, $default ) = @_;
  $default = $sizes->[0] unless defined $default;
  $self->set_option( 'default',  $default );
  $self->set_option( 'paginate', join q(_), map { $default eq $_ ? "x$_" : $_ } @{$sizes} );
  return $self;
}

sub clear_pagination {
  my $self = shift;
  $self->clear_option( 'paginate' );
  return $self;
}

sub set_title {
  my( $self, $title ) = @_;
  $self->set_option( 'title', $title );
  return $self;
}

sub clear_title {
  my $self = shift;
  $self->clear_option( 'title' );
  return $self;
}

sub set_id {
  my( $self, $id ) = @_;
  $self->set_option( 'id', $id );
  return $self;
}

sub clear_id {
  my $self = shift;
  $self->clear_option( 'id' );
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

sub set_count {
  my( $self, $count ) = @_;
  $self->set_option( 'count', $count );
  return $self;
}

sub clear_count {
  my $self = shift;
  $self->clear_option( 'count' );
  return $self;
}

sub count {
  my $self = shift;
  return $self->option( 'count' );
}

sub set_refresh_url {
  my( $self, $refresh_url ) = @_;
  $self->set_option( 'refresh_url', $refresh_url );
  return $self;
}

sub clear_refresh_url {
  my $self = shift;
  $self->clear_option( 'refresh_url');
  return $self;
}

sub refresh_url {
  my $self = shift;
  return $self->option( 'refresh_url' );
}

sub set_export_url {
  my( $self, $export_url ) = @_;
  $self->set_option( 'export_url', $export_url );
  return $self;
}

sub clear_export_url {
  my $self = shift;
  $self->clear_option( 'export_url');
  return $self;
}

sub export_url {
  my $self = shift;
  return $self->option( 'export_url' );
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
  my( $self, $class ) = @_;
  $self->{'blocks'}[ $self->{'current_block'} ]{'row_class'} = $class;
  return $self;
}

sub set_current_row_id {
  my( $self, $id ) = @_;
  $self->{'blocks'}[ $self->{'current_block'} ]{'row_id'}    = $id;
  return $self;
}

sub make_current_spanning {
  my $self = shift;
  $self->{'blocks'}[ $self->{'current_block'} ]{'spanning'}  = 1;
  return $self;
}

sub clear_current_spanning {
  my $self = shift;
  $self->{'blocks'}[ $self->{'current_block'} ]{'spanning'}  = 0;
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

sub expand_link {
  my( $self, $href_template, $val, $row, $text ) = @_;
  return q() if $text eq q();
  my $url = $self->expand_template( $href_template, $row );
  return $text unless $url;
  my $extra = q();
  if( $url =~ s{\A(.*)\s+}{}mxs ) {
    my %attrs;
    my $attr_values = $1;
    my $last_key;
    foreach ( split m{\s+}mxs, $attr_values ) {
      if( m{\A(\w+)=(.*)\Z}mxs ) {
        push @{$attrs{$1}}, $2;
        $last_key = $1;
      } else {
        $attrs{$last_key}[-1].=" $_" if $last_key;
      }
    }
    foreach (sort keys %attrs) {
      $extra .= sprintf ' %s="%s"', encode_entities($_), encode_entities( join q( ), sort @{$attrs{$_}} );
    }
  }
  return sprintf '<a%s href="%s">%s</a>', $extra, $url, $text;
}

## no critic (ExcessComplexity)
sub expand_format {
  my( $self, $format, $val ) = @_;
  my $f;
  my $val_defined = defined $val;
  $val = q() unless $val_defined;
  if( ref $format eq 'CODE' ) { ## Format can now be an array ref!
    $f = eval { &{$format}($val, $self); };
  } elsif( ref $format eq 'ARRAY' ) { ## Format can now be an array ref!
    foreach my $format_ref ( @{$format} ) {
      my( $tmp_f, $condition, @condition_pars ) = @{$format_ref};
      if( $condition ) {
        next if $condition eq 'defined'   && !$val_defined;
        next if $condition eq 'true'      && !$val;
        if( @condition_pars ) {
          next if $condition eq 'exact'     && $val ne $condition_pars[0];
          next if $condition eq 'contains'  && index $val, $condition_pars[0] < 0;
          next if $condition eq 'lt'        && $val >= $condition_pars[0];
          next if $condition eq 'gt'        && $val <= $condition_pars[0];
          next if $condition eq 'le'        && $val > $condition_pars[0];
          next if $condition eq 'ge'        && $val < $condition_pars[0];
        }
      }
      $f = $tmp_f;
      last;
    }
  } else {
    $f = $format;
  }
  $f ||= 'h';
  return $f eq 'r'                    ?                                                $val         # pass through raw!
       : $f eq 'y'                    ?                                  ($val ? 'yes' : 'no')      # render as yes no!
       : $f eq 'h'                    ? encode_entities(                               $val )       # html encode
       : $f eq 'u'                    ? uri_escape_utf8(                               $val )       # url escape
       : $f eq 'hf'                   ? $self->full_encode(                            $val )       # full html encode
       : $f eq 'uf'                   ? $self->full_escape(                            $val )       # full url escape
       : $f eq 'email'                ? $self->safe_email(                             $val )       # <a>email</a>
       : $f =~ m{\Aurl(\d*)\Z}mxs     ? $self->safe_link(                              $val, $1 )   # <a>url</a>
       : $f eq 'date'                 ? $self->time_str( $DATE_FORMAT,                 $self->munge_date_time( $val ) )
       : $f eq 'datetime'             ? $self->time_str( "$DATE_FORMAT $TIME_FORMAT",  $self->munge_date_time( $val ) )
       : $f eq 'time'                 ? $self->time_str( $TIME_FORMAT,                 $self->munge_date_time( $val ) )
       : $f =~ m{\Adatetime(.+)\Z}mxs ? $self->time_str( $1,                           $self->munge_date_time( $val ) )
       : $f eq 'currency'             ? sprintf( q(&pound;%0.2f),                      $val||0 )       # &pound;0.00
       : $f eq 't'                    ? $self->commify(                                $val )       # n,nnn,nnn,nnn
       : $f eq 'z'                    ? $self->format_size(                            $val, 0  )   # nnnn K/M/G/...
       : $f =~ m{\Az(\d+)\Z}mxs       ? $self->format_size(                            $val, $1 )   # nnnn.mm K/M/G/...
       : $f eq 'k'                    ? $self->format_fixed(                           $val, 'k', 0 ) # nnnn K
       : $f eq 'm'                    ? $self->format_fixed(                           $val, 'm', 0 ) # nnnn M
       : $f =~ m{\A([k|m])(\d+)\Z}mxs ? $self->format_fixed(                           $val, $1, $2 ) # nnnn.mm K/M
       : $f =~ m{\At(\d+)\Z}mxs       ? $self->commify( sprintf qq(%0.$1f),            $val||0 )      # n,nnn,nnn,nnn.mm
       : $f =~ m{\Af(\d+)\Z}mxs       ? sprintf( qq(%0.$1f),                           $val||0 )       # Fixed decimal
       : $f =~ m{\Apm(\d+)\Z}mxs      ? sprintf( qq(%s%0.$1f),                         $val||0>0?q(+):q(), $val||0 )       # Fixed decimal (with +/-)
       : $f =~ m{\Ab(\d+)\Z}mxs       ? $self->wbr(                                    $val, $1 )
       : $f =~ m{\Ap(\d+)\Z}mxs       ? sprintf( qq(%0.$1f%%),                         ($val||0)*$CENT ) # Percentage
       : $f eq 'p'                    ? sprintf( q(%0.2f%%),                           ($val||0)*$CENT ) # Percentage
       : $f =~ m{\Ah(\d+)\Z}mxs       ? $self->truncate_string(                        $val, $1   ) # Percentage
       : $f =~ m{\Ad(\d+)\Z}mxs       ? sprintf( qq(%0$1d),                            $val||0 )       # zero padded
       : $f eq 'd'                    ? sprintf( q(%0d),                               $val||0 )       # Integer
       :                                encode_entities(                               $val )       # HTML safe!
       ;
}

sub wbr {
  my( $self, $str, $size ) = @_;
  return join '<wbr />', map { encode_entities( $_ ) } $str =~ m{(.{1,$size})}mxsg;
}
sub truncate_string {
  my( $self, $val, $length ) = @_;
  return length $val > $length
    ? sprintf '<span title="%s">%s...</span>', encode_entities( $val ), encode_entities( substr $val, 0, $length )
    : encode_entities( $val );
}

## use critic

sub _get_val {
  my( $self, $property, $row ) = @_;
  my $v = ref $row eq 'ARRAY' ? $row->[ $property ]  ## Array ref
        : ref $row eq 'HASH'  ? $row->{ $property }  ## Hash ref
        : blessed($row)       ? $row->$property      ## Object ref
        :                       undef
        ;
  return $v;
}

sub cond_eval {
  my( $self, $str, $row ) = @_;
  return $str unless q([) eq substr $str, 0, 1;
  return $self->expand_template( $str, $row );
}

sub expand_template {
  my( $self, $template, $row ) = @_;
  my $t = $self->_expand_template( $template, $row );
  return unless defined $t;
  $t =~ s{\[\[(.*?):(\w+)\]\]}{$self->expand_format( $1, $self->_get_val( $2, $row ) ) }mxesg;
  return $t;
}

## no critic (ExcessComplexity)
sub _expand_template {
  my( $self, $template, $row ) = @_;
  return $self->_expand_template( eval { &{$template}( $row, $self ); }, $row ) if 'CODE'  eq ref $template; ## no critic (CheckingReturnValueOfEval)
  return $template                             unless 'ARRAY' eq ref $template;

  foreach my $template_ref ( @{$template} ) {
    my( $tmp_t, $condition, @condition_pars ) = @{$template_ref};
    return $tmp_t unless $condition;
    my $val = $self->_get_val( $condition_pars[0], $row );
    my $val_defined = defined $val;
    $val = q() unless $val_defined;
    my $C = @condition_pars > 1 ? $self->cond_eval($condition_pars[1], $row ) : undef;
    next if $condition eq 'exact'     && $val ne $C;
    next if $condition eq 'defined'   && ! $val_defined;
    next if $condition eq 'true'      && ! $val;
    next if $condition eq 'contains'  && (index $val, $C ) < 0;
    next if $condition eq 'lt'        && $val >= $C;
    next if $condition eq 'gt'        && $val <= $C;
    next if $condition eq 'le'        && $val >  $C;
    next if $condition eq 'ge'        && $val <  $C;
    return ref $tmp_t ? $self->_expand_template( $tmp_t, $row ) : $tmp_t;
  }
  return;
}

## use critic

sub format_value {
  my( $self, $val, $col, $row ) = @_;
  my $result = $col->{'template'} ? $self->expand_template( $col->{'template'},    $row )
                                  : $self->expand_format(   $col->{'format'}||'h', $val )
                                  ;
  $result = $self->expand_link( $col->{'link'}, $val, $row, $result ) if $col->{'link'} && $result ne q();
  return $col->{'default'}||q(&nbsp;) if !defined $result || $result eq q();
  return $result;
}

sub format_sort {
  my( $self, $val, $col, $row ) = @_;
  my $t = $self->_expand_template( $col->{'sort_index'}, $row );
  $val = defined $t ? $self->_get_val( $t, $row ) : $val;
  return $val unless exists $col->{'format'};
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
  if( exists $col->{'class'} ) {
    my $class_string = $self->expand_template( $col->{'class'}, $row );
    push @class, $class_string if $class_string;
  }
  if( $col->{'sort_index'} ) {
    my $sv = $self->format_sort( $val, $col, $row );
    push @class, sprintf '{sv:%s}', $sv||0;# if defined $sv && $sv ne q();
  }
  $extra .= sprintf q( class="%s"), join q( ), @class if @class;
  if( exists $col->{'title'} ) {
    my $title_string = $self->expand_template( $col->{'title'}, $row );
    $extra .= sprintf q( title="%s"), $title_string if $title_string;
  }
  return $extra;
}

sub other_options {
  my $self = shift;
  return join q(),
         map { $self->option( $_ ) ? sprintf ' %s="%s"', $_, encode_entities( $self->option( $_ ) ) : q() }
         qw(id title);
}

sub render_thead {
  my $self = shift;
  my @html = ( q(    <thead>), q(        <tr>) );
  foreach( $self->columns ) {
    if( $_->{'key'} eq q(#) ) {
      push @html, sprintf q(        <th>%s</th>), encode_entities( $_->{'label'}||q(#) );
    } else {
      my $meta_data = exists $_->{'meta_data'} ? $_->{'meta_data'} : {};
      if( exists $_->{'sort_index'} ) {
        $meta_data->{'sorter'} = 'metadata';
      }
      if( exists $_->{'filter_values'} ) {
        $meta_data->{'filter'} = $_->{'filter_values'};
      }
      if( exists $_->{'no_filter'} ) {
        $meta_data->{'no_filter'} = 1;
      }
      $meta_data->{'sorter'} = 'none' if exists $_->{'no_sort'};
      my @class;
      push @class, $self->encode($self->json_encode($meta_data)) if keys %{$meta_data};
      push @class, 'rotated_cell' if $_->{'rotate'};
      push @class, $_->{'header_class'} if $_->{'header_class'};
      my $extra_attributes = q();
         $extra_attributes .= sprintf q( class="%s"), join q( ), @class if @class;
         $extra_attributes .= sprintf q( style="min-width: %s"), $_->{'min-width'} if exists $_->{'min-width'};
         $extra_attributes .= sprintf q( title="%s"), encode_entities( $_->{'long_label'} ) if exists $_->{'long_label'};
      my $value = encode_entities( exists $_->{'label'} ? $_->{'label'} : $_->{'key'} );
      push @html, sprintf q(        <th%s>%s</th>), $extra_attributes, defined $value ? $value : q();
    }
  }
  push @html, q(      </tr>),q(    </thead>);
  return @html;
}

sub wrap_table {
  my $self = shift;

  my @start = (
    sprintf '  <table class="%s" summary="%s"%s>',
      $self->classes_string,
      $self->option( 'summary' )  ? encode_entities( $self->option( 'summary' ) ) : 'Automatically generated table data',
      $self->other_options(),
  );
  my @end   = ( '  </table>' );

  if( $self->option('scrollable') ) {
    unshift @start, '<div class="scrollable">';
    push @end,      '</div>';
  }

  $self->{'row_count'}  = 1;
  return ( \@start, \@end );
}

sub render {
  my $self = shift;

  ## Initialize render and get head and foot html chunks!
  my( $start, $end ) = $self->wrap_table;
  my   @html = @{$start};
  ## thead part!
  push @html, $self->render_thead     unless  $self->option( 'no-header' );
  ## tbody part!
  push @html, map { $self->render_block($_) } $self->blocks;
  push @html, @{$end};
  #push @html, @{ $self->render_totals } if $self->option( 'summary' );

  return join qq(\n), @html unless $self->option('compact');
  return join q(), map { $_=~m{\A\s*(.*)\Z}mxs ? $1 : $_ } @html;
}

sub render_first_block {
  my $self = shift;
  my $count = $self->count;
  my ($body) = $self->blocks;
  my $prefix = defined $count ? qq(<span class="hidden">$count</span>) : q();
  return $prefix unless $body;
  return $prefix.join q(),$self->render_block( $body );
}

sub reset_totals {
  my( $self, $type ) = @_; ## Type is level - 1 is block, 0 is total; - this allows for easy working with sub-blocks if required later...
  $self->{'totals'}[$type] = undef;
  return $self;
}

sub update_totals {
  my( $self, $type, $total_defn, $row ) = @_;
  return $self;
}

sub render_totals {
  my( $self, $type, $total_defn ) = @_;
  return $self;
}

sub row_attributes {
  my( $self, $block, $row ) = @_;
  my $row_extra = q();
  my $row_class = $block->{'row_class'} ? $self->expand_template( $block->{'row_class'}, $row ) : q();
  $row_extra .= sprintf ' class="%s"', $row_class if $row_class;
  my $row_id    = $block->{'row_id'}    ? $self->expand_template( $block->{'row_id'},    $row ) : q();
  $row_extra .= sprintf ' id="%s"',    $row_id    if $row_id;
  return $row_extra;
}

sub render_block {
  my( $self, $block ) = @_;
  # skip block if no data!
  return unless @{ $block->{'data'} };
  my @html;
  push @html, $block->{'class'} ? qq(    <tbody class="$block->{'class'}">) : q(    <tbody>);
  if( $block->{'spanning'} ) { ## A spanning block only has one row!
    push @html, sprintf q(      <tr%s>), $self->row_attributes( $block, $block->{'data'}[0] );
    push @html, sprintf q(        <td colspan="%d">%s</td>),
                           scalar $self->columns, $block->{'data'}[0];
    push @html, q(      </tr>),
                q(    </tbody>);
    return @html;
  }
  foreach my $row ( @{ $block->{'data'} } ) {
    push @html, sprintf q(      <tr%s>), $self->row_attributes( $block, $row );
    my $c_id = 0;
    foreach my $col ( $self->columns ) {
      my $property = $col->{'key'}||q();
      my( $value, $extra );
      if( $property eq q(#) ) {
        $value = $self->{'row_count'}++;
        $extra = ' class="r"';
      } else {
        my $v = exists $col->{'code_ref'}             ? eval { $col->{'code_ref'}($row); }
              : ref $row eq 'ARRAY'                   ? $row->[$c_id++]
              : ref $row eq 'HASH'                    ? $row->{ $col->{'key'} }
              : blessed($row) && $row->can($property) ? $row->$property
              :                                         undef
              ;
        $value = $self->format_value( $v, $col, $row );
        $extra = $self->extra_value(  $v, $col, $row );
      }
      push @html, sprintf q(        <td%s>%s</td>), $extra||q(), defined $value ? $value : q();
    }
    push @html, q(      </tr>);
  }
  push @html, q(    </tbody>);
  return @html;
}

sub parse_structure {
  my( $self, $struct ) = @_;
  my @keys = map { $_->{'key'} } $self->columns;
  return {(
    'filter'    => [ map { [ $keys[$_->[0]], $_->[1] ] } @{$struct->{'col_filters'}||[]}],
    'sort_list' => [ map { [ $keys[$_->[0]], $_->[1] ] } @{$struct->{'sort_list'}  ||[]}],
    'page'      => $struct->{'page'}||0,
    'size'      => $struct->{'size'}||$self->option('default'),
  )};
}

1;

