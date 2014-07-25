package Pagesmith::Form::Element::File;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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

use Apache2::Upload;
use base qw( Pagesmith::Form::Element );
use List::MoreUtils qw(any);
use HTML::Entities qw(encode_entities);

use Const::Fast qw(const);
const my $K                    => 1024;

my %extn_to_type = qw(
  PDF    application/pdf
  PNG    image/png
  TXT    text/plain
  GIF    image/gif
  BMP    image/bmp
  JPG    image/jpeg
  SVG    image/svg+xml
  PS     application/postscript

  DOC    application/msword
  DOT    application/msword
  RTF    application/rtf
  RTF-X  application/x-rtf

  DOCM   application/vnd.ms-word.document.macroEnabled.12
  DOTM   application/vnd.ms-word.template.macroEnabled.12
  DOCX   application/vnd.openxmlformats-officedocument.wordprocessingml.document
  DOTX   application/vnd.openxmlformats-officedocument.wordprocessingml.template

  ODT    application/vnd.oasis.opendocument.text
  ODT-X  application/x-vnd.oasis.opendocument.text

  CSV    application/vnd.ms-excel
  XLS    application/vnd.ms-excel
  XLT    application/vnd.ms-excel

  XLSB   application/vnd.ms-excel.sheet.binary.macroEnabled.12
  XLSM   application/vnd.ms-excel.sheet.macroEnabled.12
  XLTM   application/vnd.ms-excel.template.macroEnabled.12
  XLSX   application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  XLTX   application/vnd.openxmlformats-officedocument.spreadsheetml.template

  ODS    application/vnd.oasis.opendocument.spreadsheet
  ODS-X  application/x-vnd.oasis.opendocument.spreadsheet

  PPT    application/vnd.ms-powerpoint
  POT    application/vnd.ms-powerpoint

  POTM   application/vnd.ms-powerpoint.template.macroEnabled.12
  PPTM   application/vnd.ms-powerpoint.presentation.macroEnabled.12
  PPTX   application/vnd.openxmlformats-officedocument.presentationml.presentation
  POTX   application/vnd.openxmlformats-officedocument.presentationml.template

  ODP    application/vnd.oasis.opendocument.presentation
  ODP-X  application/x-vnd.oasis.opendocument.presentation
);

my $extn_groups = {
  'document'     => [qw(TXT DOC DOT RTF DOCX DOCM DOTM DOTX ODT PDF ODT-X)],
  'spreadsheet'  => [qw(TXT CSV XLS XLT XLSB XLSM XLTM XLSX XLTX ODS ODS-X)],
  'presentation' => [qw(PPT POT POTM PPTM PPTX POTX ODP PDF ODP-X)],
  'images'       => [qw(PNG GIF BMP JPG SVG PS)],
  'img_upload'   => [qw(PNG JPG)],
  'asset_upload' => [qw(DOC DOCX PDF XLS XLSX PPT PPTX)],
};

my %type_to_extn = reverse %extn_to_type;

use Pagesmith::HTML::Table;
use Pagesmith::Cache;

sub new {
  my($class,$section,$pars) = @_;
  my $self = $class->SUPER::new( $section, $pars );
  $self->{'accepted_types'} = {};
  if( exists $pars->{'multiple'} ) {
    $self->set_multiple;
  } else {
    $self->clear_multiple;
  }
  return $self;
}

sub ignore_file_uploads {
  my $self = shift;
  $self->{'ignore_file_uploads'} = 1;
  return $self;
}

sub is_empty {
  my $self = shift;
  return 0 unless $self->value ;
  return 0 if keys %{ $self->value->{'files'} || {} };
  return 1;
}

sub set_single {
  my $self = shift;
  $self->clear_multiple;
  return $self;
}

sub element_class {
  my $self = shift;
  $self->add_class( '_file' );
  return;
}

sub accept_string {
  my $self = shift;
  my @types = $self->accepted_types;
  return q() unless @types;
  return sprintf q( accept="%s"), join q(,), map { encode_entities( $_ ) } @types;
}

sub accepted_types {
  my $self = shift;
  my @keys = sort keys %{$self->{'accepted_types'}||{}};
  return @keys;
}

sub add_accepted_group {
  my( $self, @groups ) = @_;
  $self->{'accepted_types'}{$extn_to_type{( uc $_ )}} = 1
    foreach map { @{$extn_groups->{$_}||[]} } @groups;
  return $self;
}

sub add_accepted_extns {
  my( $self, @extns ) = @_;
  $self->{'accepted_types'}{$extn_to_type{( uc $_ )}} = 1
    foreach grep { exists $extn_to_type{(uc $_)} } @extns;
  return $self;
}

sub add_accepted_types {
  my( $self, @types ) = @_;
  foreach ( @types ) {
    my $key = m{/}mxs ? $_ : "$_/*";
    $self->{'accepted_types'}{$key} = 1;
  }
  return $self;
}

sub remove_accepted_types {
  my( $self, @types ) = @_;
  foreach ( @types ) {
    my $key = m{/}mxs ? $_ : "$_/*";
    delete $self->{'accepted_types'}{$key};
  }
  return $self;
}

sub get_extn_from_type {
  my( $self, $type ) = @_;
  ( my $extn = lc $type_to_extn{ $type } ) =~ s{-.+}{}mxs;
  return $extn;
}

sub remove_accepted_extns {
  my( $self, @extns ) = @_;
  delete $self->{'accepted_types'}{$extn_to_type{(uc $_)}}
    foreach grep { exists $extn_to_type{(uc $_)} } @extns;
  return $self;
}


sub clear_accepted {
  my $self = shift;
  $self->{'accepted_types'} = {};
  return $self;
}

sub render_widget {
   my $self = shift;

## Widget layout is ...
## [ form input box ]....
## If previous files uploaded and multiple...
## Table: [ idx ] [ Filename ] [ Size ] [ Summary? ] [ Delete ]
## If pervious files uploaded and single
## filename - summary [ Delete ]

  my $html = sprintf '<input type="%s" name="%s" value="%s" id="%s" class="%s"%s%s />%s',
    'file',
    encode_entities( $self->code ),
    q(),
    $self->generate_id_string,
    $self->generate_class_string,
    $self->multiple ? ' multiple="multiple"' : q(),
    $self->accept_string,
    $self->req_opt_string,
  ;
  $html .= $self->multiple ? $self->render_table( 1 ) : $self->render_single( 1 );
  return $html;
}

sub remove_uploaded_file {
  my( $self, $key ) = @_;
  Pagesmith::Cache->new( 'form_file', $key )->unset;
  delete $self->{'user_data'}[0]{'files'}{$key};
  return 1;
}

sub remove_all_uploaded_files {
  my $self = shift;
  foreach my $key ( keys %{ $self->{'user_data'}[0]{'files'} } ) {
    $self->remove_uploaded_file( $key );
  }
  return 1;
}

sub get_uploaded_file {
  my( $self, $key ) = @_;
  return Pagesmith::Cache->new( 'form_file', $key )->get;
}

sub add_uploaded_file {
  my( $self, $upload ) = @_;
  return unless $upload;
  my $size = $upload->size;
  return unless $size;
  my $content;
  $upload->slurp( $content );
  my %extra_file_info = $self->extra_file_info( $upload, \$content );
  if( exists $extra_file_info{'error'} ) { ## Do not add file if erroneous...
    return 0;
  }
  my @types = $self->accepted_types;
  if( @types ) {
    my $obj_type = $upload->type;
    my ($obj_class) = split m{/}mxs, $obj_type;
    return 0 unless any { $obj_type eq $_ || "$obj_class/*" eq $_ } @types;
  }
  my $prefix = $self->form_config->option('code').q(|).$self->code;
  $self->{'user_data'}[0]{'next_idx'}||=1;
  my $next_idx = $self->{'user_data'}[0]{'next_idx'}++;
  my $key = "$prefix|$next_idx";

  Pagesmith::Cache->new( 'form_file', $key )->set( $content );
  $self->{'user_data'}[0]{'files'}{$key} = {
    'ndx'   => $next_idx,
    'size'  => $size,
    'type'  => $upload->type,
    'name'  => $upload->filename,
    'xtn'   => $self->get_extn_from_type( $upload->type ),
    %extra_file_info,
  };
  return 1;
}

sub extra_file_info {
  my($self,$upload) = @_;
  return;
}

sub update_from_apr {
  my( $self, $apr ) = @_;
  return if $self->{'ignore_file_uploads'};
  my @uploads  = $apr->upload( $self->code );
  ## Loop through all the checkboxes and delete attached files...
  my $del_all = $apr->param( $self->code.'_del_all' ) ? 1 : 0;
  $del_all = 2 if !$self->multiple && @uploads && any { $_ } @uploads;
  foreach my $key ( keys %{ $self->{'user_data'}[0]{'files'} } ) {
    my $idx = $self->{'user_data'}[0]{'files'}{$key}{'ndx'};
    $self->remove_uploaded_file( $key ) if $del_all || $apr->param( $self->code.'_del_'.$idx );
  }

  if( $self->multiple ) {
    ## Loop through all files and add them....
    foreach( @uploads ) {
      $self->add_uploaded_file( $_ );
    }
  } else {
    ## Take the single entry and replace it!
    $self->add_uploaded_file( $uploads[0] ) if @uploads;
  }
  return;
}

sub extra_columns {
  my $self = shift;
  return ();
}

sub render_widget_readonly {
  my $self = shift;
  return $self->multiple ? $self->render_table( 0 ) : $self->render_single( 0 );
}

sub expand {
  my( $self, $string, $entry ) = @_;
  $string =~s{\[\[h:(\w+)\]\]}{encode_entities( $entry->{$1} )}mxsg;
  return $string;
}

sub render_email {
  my( $self, $form ) = @_;
  my ($entry) = values %{$self->{'user_data'}[0]{'files'}||{}};
  my $prefix = $self->form_config->option('code').q(/).$self->code;
  return $self->SUPER::render_email( sprintf qq(%s (%0.1fk %s)\n%s/action/FormFile/%s/%d/%s-%d.%s),
    $entry->{'name'}, $entry->{'size'}/$K, $entry->{'type'},
    $self->base_url($self->{'r'}),
    $prefix, $entry->{'ndx'}, $prefix, $entry->{'ndx'}, $self->get_extn_from_type( $entry->{'type'} ),
  );
}

sub render_single {
  my($self,$flag) = @_;
  ## Get first value....
  my ($entry) = values %{$self->{'user_data'}[0]{'files'}||{}};
  return q() unless $entry; # '<p>No files currently attached</p>' unless $entry;
  ## no critic (ImplicitNewlines)
  my $prefix = $self->form_config->option('code').q(/).$self->code;

  return sprintf '
  <div class="file-details">
  <dl class="twocol">
    <dt>Name</dt><dd><a rel="external" href="/action/FormFile/%s/%d/%s-%d.%s">%s</a></dd>
    <dt>Size</dt><dd>%0.1fk</dd>
    <dt>Type</dt><dd>%s</dd>
    %s
  </dl>
  </div>',
    $prefix, $entry->{'ndx'},$prefix,$entry->{'ndx'}, $entry->{'xtn'},
    encode_entities( $entry->{'name'} ),
    $entry->{'size'}/$K, $entry->{'type'},
    !$flag ? q() : sprintf '<dt>Delete?</dt><dd><input type="checkbox" class="checkbox _cb_%s" id="%s_del_%d" name="%s_del_%d" value="delete" /></dd>',
      $self->code, $self->generate_id_string,  $entry->{'ndx'}, $self->code, $entry->{'ndx'};
  ## use critic
}

sub get_file_info{
  my $self = shift;
  return values %{$self->{'user_data'}[0]{'files'}||{}};
}

sub render_table {
  my($self,$flag) = @_;

  my @rows = values %{$self->{'user_data'}[0]{'files'}||{}};
  return q() unless @rows;## '<p>No files currently attached</p>' unless @rows;

  my $prefix = $self->form_config->option('code').q(/).$self->code;

  my @columns = (
    ##{ 'key' => 'ndx',  'label' => 'Index', 'align' => 'right' },
    { 'key' => 'name', 'label' => 'Name', 'link' => "/action/FormFile/$prefix/[[d:ndx]]/$prefix-[[d:ndx]].[[h:xtn]]" },
    { 'key' => 'type', 'label' => 'Type', },
    { 'key' => 'size', 'label' => 'Size', 'align' => 'right', 'format' => 'k1' },
    $self->extra_columns,
  );

  push @columns,
    { 'key' => 'delete', 'label' => 'Delete', 'align' => 'center',
      'template' => sprintf '<input class="checkbox _cb_%s" type="checkbox" id="%s_del_[[h:ndx]]" name="%s_del_[[h:ndx]]" value="delete" />',
      $self->code, $self->generate_id_string,  $self->code,
    } if $flag;
  ## no critic (LongChainsOfMethodCalls)
  my $table = Pagesmith::HTML::Table->new( $self->r )
    ->set_current_row_class( 'file-details' )
    ->add_columns( @columns )
    ->add_data( sort { $a->{'ndx'} <=> $b->{'ndx'} } values %{$self->{'user_data'}[0]{'files'}||{}} );
  $table->add_block( 'foot', { 'name' => 'ALL', 'ndx' => 'all' } )
        ->set_current_row_class( 'file-details', 'delete-all' ) if $flag;
  ## use critic
  $table->make_sortable if $self->multiple;
  return $table->render;
}

sub render_value {
  my $self = shift;
  return $self->pre_dumper( $self->value );
}

sub has_file {
  return 1;
}

sub has_file_no_ignored {
  my $self = shift;
  return $self->{'ignore_file_uploads'} ? 0 : 1;
}

sub widget_type {
  return 'file';
}

sub validate {
  my $self = shift;
  return $self->set_valid;
}

sub png_or_jpg {
  my $self = shift;
  return $self->jpg->png;
}

sub jpg {
  my $self = shift;
  return $self->add_accepted_types( qw(
    image/jpeg image/jpg image/pipeg image/pjpeg image/vnd.swiftview.jpeg
    application/x-jpg
  ) );
}

sub png {
  my $self = shift;
  return $self->add_accepted_types( qw(image/png application/x-png) );
}

sub pdf {
  my $self = shift;
  return $self->add_accepted_types( qw(
    application/pdf application/x-pdf application/vnd.pdf application/acrobat
    text/pdf text/x-pdf) );
}

sub generics {
  my $self = shift;
  return $self->add_accepted_types( qw(application/x-download application/octet-stream) );
}

1;
__END__

General:

PDF  = application/pdf
PNG  = image/png
TXT  = text/plain
GIF  = image/gif
BMP  = image/bmp
JPG  = image/jpeg
SVG  = image/svg+xml
PS   = application/postscript

Documents:

DOC  = application/msword
DOT  = application/msword
RTF  = application/msword

DOCX = application/vnd.ms-word.document.12
DOCM = application/vnd.ms-word.document.macroEnabled.12
DOTM = application/vnd.ms-word.template.macroEnabled.12
DOTX = application/vnd.openxmlformats-officedocument.wordprocessingml.template

ODT  = application/vnd.oasis.opendocument.text

Spreadsheets:

CSV  = application/vnd.ms-excel
XLS  = application/vnd.ms-excel
XLT  = application/vnd.ms-excel

XLSB = application/vnd.ms-excel.sheet.binary.macroEnabled.12
XLSM = application/vnd.ms-excel.sheet.macroEnabled.12
XLTM = application/vnd.ms-excel.template.macroEnabled.12
XLSX = application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
XLTX = application/vnd.openxmlformats-officedocument.spreadsheetml.template

ODS  = application/vnd.oasis.opendocument.spreadsheet

Presentations:

PPT  = application/vnd.ms-powerpoint
POT  = application/vnd.ms-powerpoint

POTM = application/vnd.ms-powerpoint.template.macroEnabled.12
PPTM = application/vnd.ms-powerpoint.presentation.macroEnabled.12
PPTX = application/vnd.openxmlformats-officedocument.presentationml.presentation
POTX = application/vnd.openxmlformats-officedocument.presentationml.template

ODP  = application/vnd.openxmlformats-officedocument.presentationml.template

