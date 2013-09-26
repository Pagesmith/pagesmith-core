package Pagesmith::Action;

## Base class to handle web /action/ urls...
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

use Const::Fast qw(const);
const my $FUTURE     => 0x7fffffff;
const my $ONE_YEAR   => 31_622_400;
const my $ONE_WEEK   =>    604_800;
const my $ONE_DAY    =>     86_400;
const my $ONE_HOUR   =>      3_600;
const my $ONE_MINUTE =>         60;

use base qw(Pagesmith::Support);

use Apache2::Const qw(REDIRECT OK SERVER_ERROR FORBIDDEN NOT_FOUND HTTP_NO_CONTENT HTTP_BAD_REQUEST DONE);
use Apache2::Response;
use Apache2::Request;
use Apache2::Util;
use Date::Format qw(time2str);
use HTML::Entities qw(encode_entities);
use English qw(-no_match_vars $PID);
use Encode ();
use Spreadsheet::WriteExcel;

use Pagesmith::Message;
use Pagesmith::ConfigHash qw(can_cache get_config);
use Pagesmith::Core qw(parse_cookie);

use Pagesmith::Apache::Decorate;
use Pagesmith::HTML::Table;
use Pagesmith::HTML::Tabs;
use Pagesmith::HTML::TwoCol;
use Pagesmith::Form::Stub;
use Pagesmith::Utils::FormObjectCreator;

sub do_not_throw_extra_error {
  my $self = shift;
  $self->r->pnotes( 'do_not_throw_error_page', 1 );
  return $self;
}
sub can_ajax {
  my $self = shift;
  my $flags = parse_cookie($self->r)||{};
  return exists $flags->{'a'} && $flags->{'a'} eq 'e';
}

sub type {
  my $self = shift;
  unless( exists $self->{'_action_type'} ) {
    ( $self->{'_action_type'} = ref $self ) =~ s{\APagesmith::Action::}{}mxs;
  }
  return $self->{'_action_type'};
}

sub user {
  my $self = shift;
  return $self->SUPER::user( $self->r );
}

sub no_qr {
  my( $self, @pars ) = @_;
  $self->r->headers_out->set( 'X-Pagesmith-NoQr', 1 );
  return $self;
}

sub no_spell {
  my( $self, @pars ) = @_;
  $self->r->headers_out->set( 'X-Pagesmith-NoSpell', 1 );
  return $self;
}

sub no_spell_at_all {
  my( $self, @pars ) = @_;
  $self->r->headers_out->set( 'X-Pagesmith-NoSpell', 2 );
  return $self;
}

sub stub_form {
  my( $self, $pars ) = @_;
  return Pagesmith::Form::Stub->new( {( %{$pars||{}}, 'r' => $self->r, 'apr' => $self->apr )} );
}

sub form {
  my( $self, @type_and_key ) = @_;
  return Pagesmith::Utils::FormObjectCreator->new( $self->r, $self->apr )->form_from_type( @type_and_key );
}

sub form_by_code {
  my( $self, $code ) = @_;
  return Pagesmith::Utils::FormObjectCreator->new( $self->r, $self->apr )->form_from_code( $code );
}

sub generic_form {
  my( $self, @type_and_key ) = @_;
  return Pagesmith::Utils::FormObjectCreator->new( $self->r, $self->apr )->generic_form( @type_and_key );
}

sub table {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::Table->new( $self->r, @pars );
}

sub twocol {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::TwoCol->new( @pars );
}

sub tabs {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::Tabs->new( @pars );
}

sub fake_tabs {
  my( $self, @pars ) = @_;
  return $self->tabs( @pars )->set_option( 'fake', 1 );
}

sub hidden_tabs {
  my( $self, @pars ) = @_;
  @pars = {} unless @pars;
  $pars[0]{'fake'}=1;
  return $self->tabs( @pars )->add_classes('hidden');
}

sub second_tabs {
  my( $self, @pars ) = @_;
  @pars = {} unless @pars;
  $pars[0]{'fake'}=1;
  $pars[0]{'no_heading'}=1;
  return $self->tabs( @pars )->add_classes('second-tabs');
}

sub push_message {
## Push a message onto the message stack!
  my ( $self, @msgs ) = @_;
  push @{ $self->{'_messages'} }, Pagesmith::Message->new(@msgs);
  return $self;
}

sub tmp_filename {
## Return a temporary file name - that exists on real disk! - we may later delete
## this!
  my ( $self, $xtn ) = @_;
  return get_config('RealTmp') . $PID . q(.) . time() . ( defined $xtn ? qq(.$xtn) : q() );
}

sub set_length {
  my( $self, $length ) = @_;
  $self->r->set_content_length( $length );
  return $self;
}

sub pdf_print {
  my ( $self, $pdf ) = @_;
  my $string = $pdf->stringify;
  return $self->pdf->set_length( length $string )->print( $string )->ok;
}

sub json_print {
  my ( $self, $scalar ) = @_;
  my $string = $self->json_encode( $scalar );
  return $self->json->set_length( length $string )->print( $string )->ok;
}

sub excel_print {
  my( $self, $head_data, $body_data ) = @_;
  my $str;
  ## no critic (BriefOpen)
  if( open my $fh, q(>), \$str ) {
    my $workbook  = Spreadsheet::WriteExcel->new($fh);
    my $worksheet = $workbook->add_worksheet;
    my $header = $workbook->add_format;
    $header->set_bold;
    my $r = 0;
    foreach my $row ( @{$head_data} ) {
      $worksheet->write( $r++, 0, $row, $header );
    }
    foreach my $row ( @{$body_data} ) {
      $worksheet->write( $r++, 0, $row );
    }
    $workbook->close;
    $self->excel->print( $str )->set_length( length $str );
    close $fh; ## no critic (RequireChecked)
    return $self->ok;
  }
  ## use critic
  return $self->no_content;
}

sub csv_print {
  my( $self, @display_data ) = @_;
  my $str = join "\n", map { $self->csv_string( $_ ) } @display_data;
  return $self->csv->print( $str )->set_length( length $str )->ok;
}

sub csv_line {
  my( $self, @line ) = @_;
  @line = ${$line[0]} if @line && ref $line[0];
  $self->csv_handler->combine( @line );
  return $self->csv_handler->string;
}

sub csv_string {
  my( $self, $display_data ) = @_;
  my @out;
  foreach( @{$display_data} ) {
    $self->csv_handler->combine( @{$_} );
    push @out, $self->csv_handler->string;
  }
  return join "\n", @out;
}

sub tsv_print {
  my( $self, @display_data ) = @_;
  my $str = join "\n", map { $self->tsv_string( $_ ) } @display_data;
  return $self->tsv->print( $str )->set_length( length $str )->ok;
}

sub tsv_line {
  my( $self, @line ) = @_;
  @line = ${$line[0]} if @line && ref $line[0];
  return join qq(\t), map { Encode::encode('iso-8859-1',$_) } @line;
}

sub tsv_string {
  my( $self, $display_data ) = @_;
  return join qq(\n), map { join qq(\t), map { Encode::encode('iso-8859-1',$_) } @{$_} } @{$display_data};
}

sub xml_print {
  my ( $self, $xml ) = @_;
  return $self->xml->print( $xml )->ok;
}

sub json_cache_print {
  my ( $self, $scalar ) = @_;
  return $self->json->cache_print( $self->json_encode( $scalar ) )->ok;
}

sub download {
  my( $self, $filename, $string_ref ) = @_;
  return $self->download_as( $filename )->set_length( length ${$string_ref} )->print( ${$string_ref} )->ok;
}

sub download_as {
  my( $self, $filename ) = @_;
  $self->r->headers_out->set('Content-Disposition' => 'attachment; filename='.$filename );
  return $self;
}

sub last_modified {
  my ( $self, $time ) = @_;
  $time ||= time;
  $self->r->headers_out->set( 'Last-modified', time2str( '%a, %d %b %Y %H:%M:%S %Z', $time, 'GMT' ) );
  return $self;
}

sub trim {
  my( $self, $str ) = @_;
  return scalar reverse unpack 'A*',reverse unpack 'A*',$str;
}

sub _trim {
  my( $self, $str ) = @_;
  return unless defined $str;
  $str =~ s{\s+}{ }mxgs;
  return scalar reverse unpack 'A*',reverse unpack 'A*',$str;
}

sub content {
  my $self = shift;
  return join q(), @{ $self->{'_content'} };
}

sub cache_print {
  my( $self, @content ) = @_;
  $self->r->print( @content );
  push @{ $self->{'_content'} }, @content;
  return $self;
}

sub enable_caching {
  my $self = shift;
  $self->{'_cache'} = 1;
  return $self;
}

sub caching {
  my $self = shift;
  return $self->{'_cache'};
}

sub disable_caching {
  my $self = shift;
  $self->{'_cache'} = 0;
  return $self;
}

sub extra_url_info {
  my $self = shift;
  return $self->{'_extra'};
}

sub new {
  my $class = shift;
  my $pars  = shift;
  my $self  = {
    '_path_info' => $pars->{'path_info'} || [],
    '_r'         => $pars->{'r'},
    '_extra'     => $pars->{'extra'}     || {},
    '_apr'       => undef,
    '_cache'     => 0,
    '_content'   => [],
    '_messages'  => $pars->{'r'}->pnotes( 'errors' ),
  };
  bless $self, $class;
  return $self;
}

sub param {
  my ( $self, @param ) = @_;
  return $self->apr->param(@param);
}

sub trim_param {
  my ( $self, @param ) = @_;
  return $self->_trim( $self->apr->param(@param) );
}

sub r {
  my $self = shift;
  return $self->{'_r'};
}

sub env {
  my ( $self, @param ) = @_;
  return $self->{'_r'}->subprocess_env(@param);
}

sub reset_path_info {
  my( $self, @parts ) = @_;
  $self->{'_path_info'} = \@parts;
  return $self;
}

sub next_path_info {
  my $self = shift;
  return shift @{ $self->{'_path_info'} };
}

sub path_info {
  my $self = shift;
  return @{ $self->{'_path_info'} };
}

sub path_info_part {
  my( $self, $index ) = @_;
  return if $index >= @{ $self->{'_path_info'} };
  return $self->{'_path_info'}[$index];
}

sub content_type {
  my( $self, $type ) = @_;
  $self->r->content_type( $type );
  return $self;
}

sub json {
  my $self = shift;
  return $self->content_type( 'application/json; charset=utf-8' );
}

sub pdf {
  my $self = shift;
  return $self->content_type( 'application/pdf; charset=utf-8' );
}

sub html {
  my $self = shift;
  ## This is where we can attach the filter!
  $self->r->add_output_filter( \&Pagesmith::Apache::Decorate::handler ); ## no critic (CallsToUnexportedSubs)
  return $self->content_type('text/html; charset=utf-8');
}

sub text {
  my $self = shift;
  return $self->content_type('text/plain; charset=utf-8');
}

sub tsv {
  my $self = shift;
  return $self->content_type('text/tab-separated-values; charset=utf-8');
}

sub excel {
  my $self = shift;
  return $self->content_type('application/vnd.ms-excel');
}

sub csv {
  my $self = shift;
  return $self->content_type('text/csv; charset=utf-8');
}

sub xml {
  my $self = shift;
  return $self->content_type('application/xml; charset=utf-8');
}

sub rss {
  my $self = shift;
  return $self->content_type('application/rss+xml; charset=utf-8');
}

##no critic (BuiltinHomonyms)
sub print {
#@param (self)
#@param (string+) @vals - list of strings to interpolate into template
#@return ($self) so can be chained!

## Does "print" on the Apache output handle!
  my ( $self, @vals ) = @_;
  push @{$self->{'_content'}}, @vals if @vals && $self->caching;
  $self->r->print(grep { defined $_ } @vals) if @vals;
  return $self;
}

sub say {
#@param (self)
#@param (string+) @vals - list of strings to interpolate into template
#@return ($self) so can be chained!

## Does "print" on the Apache output handle!
  my ( $self, @vals ) = @_;
  push @{$self->{'_content'}}, @vals if @vals && $self->caching;
  $self->r->print(grep { defined $_ } @vals) if @vals;
  push @{$self->{'_content'}},"\n";
  $self->r->print("\n");
  return $self;
}

sub printf {
#@param (self)
#@param (string) $template - printf template to expand out
#@param (string+) @vals - list of strings to interpolate into template
#@return ($self) so can be chained!
## Does "printf" on the Apache output handle!
  my ( $self, $template, @vals ) = @_;
  my $interpolated = sprintf $template, @vals;
  push @{$self->{'_content'}}, $interpolated if $self->caching;
  $self->r->print( $interpolated );
  return $self;
}
##use critic

sub args {
#@param (self)
#@return (string) current query string for page
## gets the query string off the apache RequestRec object

  my $self = shift;
  return $self->r->args;
}

sub ok {
  return OK;
}

sub forbidden {
  return FORBIDDEN;
}

sub not_found {
  return NOT_FOUND;
}

sub no_content {
  return HTTP_NO_CONTENT;
}

sub bad_request {
  return HTTP_BAD_REQUEST;
}

sub server_error {
  return SERVER_ERROR;
}

sub login_required {
  my $self = shift;
  $self->r->pnotes( 'error-reason', 'login-required' );
  return FORBIDDEN;
}

sub no_permission {
  my $self = shift;
  $self->r->pnotes( 'error-reason', 'no-permission' );
  return FORBIDDEN;
}

sub is_post {
  my $self = shift;
  return $self->r->method eq 'POST';
}

sub done {
  my $self = shift;
  return DONE;
}

sub redirect {
#@param (self)
#@param (string) $url URL to redirect to
#@return (number) Apache "REDIRECT" response status code (allows the result to be used in lines like return $self->redirect($url) if $condition; )
  my ( $self, $url ) = @_;
  # This is a roundabout method as we can't use standard returning REDIRECT code
  # and it work with the error handler - instead we have to set the status,
  # status line, headers, location separately AND return "DONE" to say it has
  # finished
  $self->r->headers_out->set( 'Location' => $url );
  $self->r->headers_out->set( 'Status'   => '302 Found' );
  $self->r->status_line( 'HTTP/1.1 302 Found' );
  $self->r->status(      '302' );
  return DONE;
}

sub no_decor {
#@param (self)
## Sets the X-Pagesmith-Decor header to "no" so the output filters won't wrap the page.
  my $self = shift;
  $self->r->headers_out->set( 'X-Pagesmith-Decor', 'no' );
  return $self;
}

sub wrap {
#@param (self)
#@param (string) $subject title of page - to go in HTML header and h2 tag
#@param (string) $body content of page to display
#@return (self)
## Sets the content type to text/html && outputs a simple wrapped HTML page - this page is further wrapped by the output filters to include appropriate headers and footers
  my ( $self, $subject, $body ) = @_;
  ##no critic (ImplicitNewlines)
  return $self->html->printf( '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <title>%s</title>
</head>
<body>
  <h2>%s</h2>
  %s
</body>
  </html>', encode_entities($subject), encode_entities($subject), $body );
  ##use critic (ImplicitNewlines)
}

sub wrap_rhs {
#@param (self)
#@param (string) $subject title of page - to go in HTML header and h2 tag
#@param (string) $body content of page to display
#@return (self)
## Sets the content type to text/html && outputs a simple wrapped HTML page - this page is further wrapped by the output filters to include appropriate headers and footers
  my ( $self, $subject, $body, $rhs ) = @_;
  ##no critic (ImplicitNewlines)
  return $self->html->printf( '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <title>%s</title>
</head>
<body>
  <div id="main">
    %s
  </div>
  <div id="rhs">
    %s
  </div>
</body>
  </html>', encode_entities($subject), $body, $rhs );
  ##use critic (ImplicitNewlines)
}

sub wrap_no_heading {
#@param (self)
#@param (string) $subject title of page - to go in HTML header and h2 tag
#@param (string) $body content of page to display
#@return (self)
## Sets the content type to text/html && outputs a simple wrapped HTML page - this page is further wrapped by the output filters to include appropriate headers and footers
  my ( $self, $subject, $body ) = @_;
  ##no critic (ImplicitNewlines)
  return $self->html->printf( '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <title>%s</title>
</head>
<body>
  %s
</body>
  </html>', encode_entities($subject), $body );
  ##use critic (ImplicitNewlines)
}

sub cache_key {
#@param (self)
#@return (string|undef) flag to indicate whether or not this component can be cached, and if so the name of the key to use
## If the server does not cache components return undef, otherwise call the _cache_key function on the component itself

  my $self = shift;
  return unless can_cache('actions');
  return join '__', $self->_cache_key();    ## Join the cache key / merge with double "_" signs...
}

sub _cache_key {
#@param (self)
#@return (array) Array of strings defining the cache key.
## This function is over-riden in the child module if required
  return ();
}

sub cache_expiry {
#@param (self)
#@return (number) numeric value to set the cache expiry to.
## This function is over-riden in the child module if required, <0 cache for given period of time, =0 cache forever, >0 cache till specified time
  return 0;
}

sub set_last_modified {
  my( $self, $time ) = @_;
  $self->r->headers_out->set( 'Last-modified', Apache2::Util::ht_time( $self->r->pool, $time ) ); ## no critic(CallsToUnexportedSubs)
  return $self;
}
sub set_expires_header {
#@param (self)
#@param (int)? $duration Duration in units if set (or to a timestamp if $unit eq 'TIMESTAMP'
#@param (string)? $unit unit of time, MINUTE|HOUR|WEEK|DAY|YEAR or TIMESTAMP
#@return (self)
## Sets the expires header based on parameters - if no parameters then sets it to "never" expire... i.e. end of unix time 2037!
  my( $self, $duration, $unit ) = @_;
  my $current_time = time;
  if( defined $duration ) {
    $unit = 'YEAR' unless defined $unit;
    if( $unit eq 'TIMESTAMP' ) { ## Set to explicit time stamp
      $duration = $duration - $current_time;
    } else {
      $duration *= $unit eq 'YEAR'   ? $ONE_YEAR
                 : $unit eq 'DAY'    ? $ONE_DAY
                 : $unit eq 'WEEK'   ? $ONE_WEEK
                 : $unit eq 'HOUR'   ? $ONE_HOUR
                 : $unit eq 'MINUTE' ? $ONE_MINUTE
                 :                    1
                 ;
    }
  } else {
    $duration = $FUTURE - $current_time;
  }
  $self->r->headers_out->set( 'Expires', Apache2::Util::ht_time( $self->r->pool, $current_time + $duration ) ); ## no critic(CallsToUnexportedSubs)
  $self->r->headers_out->set( 'Cache-Control',  "max-age=$duration,public" );
  return $self;
}

sub is_xhr {
  my $self = shift;
  my $xhr_header = $self->r->headers_in->get('X-Requested-With') || q();
  return 1 if $xhr_header eq 'XMLHttpRequest' || $self->param('_xhr_');
  return;
}

sub init_store {

#@param (self)
#@param (string) $key
#@param (*) $default
#@return (*) contents of "storage" element
## Creates a named "storage" element on the Page object (to allow information
## to be parsed between multiple Components in the page (e.g. Cite and References)

  my ( $self, $key, $default ) = @_;
  my $store = $self->r->pnotes('_store');
  unless( $store ) {
    $store = {};
    $self->r->pnotes('_store',$store);
  }
  return $store->{$key} ||= $default;
}

sub store_exists {
  my ( $self, $key ) = @_;
  my $store = $self->r->pnotes('_store');
  return $store && exists $store->{$key};
}

sub set_store {

#@param (self)
#@param (string) $key
#@param (*) $value
#@return (*) contents of named "storage" element
## Sets the named "storage" element on the Page object
  my ( $self, $key, $value ) = @_;
  my $store = $self->r->pnotes('_store');
  unless( $store ) {
    $store = {};
    $self->r->pnotes('_store',$store);
  }
  return $store->{$key} = $value;
}

sub remove_store {

#@param (self)
#@param (string) $key
## Removes the named "storage" element on the Page object
  my ( $self, $key ) = @_;
  my $store = $self->r->pnotes('_store');
  delete $store->{$key} if $store;
  return;
}

sub get_store {

#@param (self)
#@param (string) $key
#@return (*) contents of "storage" element
## Retrieves the named "storage" element on the Page object
  my ( $self, $key ) = @_;
  my $store = $self->r->pnotes('_store');
  return $store->{$key} if $store;
  return;
}

1;
