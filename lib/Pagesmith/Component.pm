package Pagesmith::Component;

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

use base qw(Pagesmith::Support);

use URI::Escape qw(uri_escape_utf8);
use Data::Dumper;
use English qw(-no_match_vars $EVAL_ERROR);
use HTML::Entities qw(encode_entities decode_entities);
use Text::ParseWords qw(shellwords);    ## Parsing parameters for components
use Time::HiRes qw(time);

use Pagesmith::Core qw(safe_md5);
use Pagesmith::HTML::Table;
use Pagesmith::HTML::Tabs;
use Pagesmith::HTML::TwoCol;
use Pagesmith::Utils::FormObjectCreator;

#@property (Pagesmith::Page) _page Page object.
#@property (arrayref{}) _options Hashref of arrayrefs containing options passed in <% %>
#@property (string[]) _pars Array of parameters passed inside the <% %> tags

sub user {
  my $self = shift;
  return $self->page->user;
}

sub r {
  my $self = shift;
  return $self->page->r;
}

sub apr {
  my $self = shift;
  return $self->page->apr;
}

sub _trim {
  my $self = shift;
  my $x = shift;
  return unless defined $x;
  $x =~ s{\s+}{ }mxgs;
  $x =~ s{\A\s+}{}mxs;
  $x =~ s{\s+\Z}{}mxs;
  return $x;
}

sub param {
  my ( $self, @param ) = @_;
  return $self->apr->param(@param);
}

sub trim_param {
  my ( $self, @param ) = @_;
  return $self->_trim( $self->apr->param(@param) );
}

sub _parse {
  my( $self, $html ) = @_;
  ${$html} =~ s{<%\s+([A-Z][\w:]+)\s+(%>|(.*?)\s+%>)}{$self->page->execute( $1, $3 )}mxesg;

  ## Hide any content marked as <% hide %>..<% end %>
  ## <% If %> directive either returns <% hide %> or <% show %>
  ${$html} =~ s{<%\s+hide\s+%>.*?<%\s+end\s+%>}{}mxsg;
  ${$html} =~ s{<%\s+show\s+%>(.*?)<%\s+end\s+%>}{$1}mxsg;
  return;
}

sub new {

#@param (class)
#@param (Pagesmith::Page) Page object
#@return (self)
## Constructor

  my $class = shift;
  my $self = { '_page' => shift, '_options' => {}, '_pars' => [], '_output' => [] };
  bless $self, $class;
  return $self;
}

sub init_store {

#@param (self)
#@param (string) $key
#@param (*) $default
#@return (*) contents of "storage" element
## Creates a named "storage" element on the Page object (to allow information
## to be parsed between multiple Components in the page (e.g. Cite and References)

  my ( $self, $key, $default ) = @_;
  return $self->{'_page'}{'_store'}{$key} ||= $default;
}

sub store_exists {
  my ( $self, $key ) = @_;
  return exists $self->{'_page'}{'_store'}{$key};
}
sub set_store {

#@param (self)
#@param (string) $key
#@param (*) $value
#@return (*) contents of named "storage" element
## Sets the named "storage" element on the Page object
  my ( $self, $key, $value ) = @_;
  return $self->{'_page'}{'_store'}{$key} = $value;
}

sub remove_store {

#@param (self)
#@param (string) $key
## Removes the named "storage" element on the Page object
  my ( $self, $key ) = @_;
  delete $self->{'_page'}{'_store'}{$key};
  return;
}

sub get_store {

#@param (self)
#@param (string) $key
#@return (*) contents of "storage" element
## Retrieves the named "storage" element on the Page object
  my ( $self, $key ) = @_;
  return $self->{'_page'}{'_store'}{$key};
}

sub ajax {

#@param (self)
#@return (string) flag to indicate whether this Component can be loaded via AJAX
## This function is over-riden in the child module if required
## +responses are 1 or 'click' and|or 'no-cache'
  return 0;
}


sub ajax_message {

#@param (self)
#@return (HTML) HTML to display in AJAX placeholder
## This function is over-riden in the child module if required
  return 'Loading...';
}


sub cache_key {

#@param (self)
#@return (string|undef) flag to indicate whether or not this component can be cached, and if so the name of the key to use
## If the server does not cache components return undef, otherwise call the _cache_key function on the component itself

  my $self = shift;
  return unless $self->page->can_cache('components');
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

sub encode {

#@param (self)
#@param (string) String to be escaped
#@return (string) HTML encoded version of string
  my $self = shift;
  return encode_entities(shift);
}

sub url_encode {

#@param (self)
#@param (string) String to be escaped
#@return (string) URL encoded version of string
  my $self = shift;
  return uri_escape_utf8(shift);
}

sub page {

#@param (self)
#return (Pagesmith::Page) Attached page object
## accessor (read-only)
  my $self = shift;
  return $self->{'_page'};
}

sub options {

#@param (self)
#return (hashref) Options hash ref
## accessor (read-only)
  my $self = shift;
  return $self->{'_options'};
}

sub next_par {
#@param (self)
#return (scalar) first parameter
## accessor (read-only)
  my $self = shift;
  return shift @{ $self->{'_pars'} };
}

sub pars {
#@param (self)
#return (array) array of parameters
## accessor (read-only)
  my $self = shift;
  return @{ $self->{'_pars'} };
}

sub _error {
  my ( $self, $msg ) = @_;
  return qq(<span class="web-error">$msg</span>);
}

sub push_message {
  my ( $self, @msgs ) = @_;
  $self->page->push_message(@msgs);
  return;
}

sub parse_parameters {
  my ( $self, $pars ) = @_;

  my @p = eval {
    map { decode_entities($_) } shellwords($pars);
  };
  if ($EVAL_ERROR) {
    $self->push_message( "Unable to parse parameters for directive\n($pars);\nmessage: $EVAL_ERROR", 'error' );
    return;
  }
  my $opt_flag = 1;
  foreach (@p) {
    if ( $_ eq q(--) ) {
      $opt_flag = 0;
    } elsif ( $opt_flag && m{\A-(.*?)(=(.*))?\Z}mxs ) {
      push @{ $self->{'_options'}{$1} }, defined $3 && $3 ne q() ? $3 : 1;
    } else {
      push @{ $self->{'_pars'} }, $_;
      $opt_flag = 0;
    }
  }
  return;
}

sub checksum_parameters {
  my $self = shift;
## Dumper in object mode returns self from config functions so the following is safe!
##no critic (LongChainsOfMethodCalls)
  return (
    @{ $self->{'_pars'} }
    ? safe_md5( Data::Dumper->new( [$self->{'_pars'}], ['pars'] )->Terse(1)->Indent(0)->Dump() )
    : q(),
    %{ $self->{'_options'} }
    ? safe_md5( Data::Dumper->new( [$self->{'_options'}], ['options'] )->Terse(1)->Indent(0)->Sortkeys(1)->Dump() )
    : q(),
  );
##use critic (LongChainsOfMethodCalls)
}

sub option {
  my( $self, $key, $default ) = @_;
  unless( exists $self->{'_options'}{$key} ) {
    return $default unless ref $default eq 'ARRAY';
    return wantarray ? @{$default} : $default->[0];
  }
  my @vals = @{ $self->{'_options'}{$key} || [] };
  return
      wantarray ? @vals
    : @vals     ? $vals[-1]
    :             undef;
}

sub _qs {
  my $self = shift;
  my $apr  = $self->page->apr;
  my @pairs;
  foreach my $param ( sort $apr->param ) {
    my $eparam = uri_escape_utf8($param);
    foreach my $value ( $apr->param($param) ) {
      next unless defined $value;
      $value = uri_escape_utf8($value);
      push @pairs, "$eparam=" . uri_escape_utf8($value);
    }
  }
  return join q(;), sort @pairs;
}

sub execute {
  my $self = shift;
  return $self->_error( 'The component "' . encode_entities( ref $self ) . '" has not been created yet' );
}

sub wrap {
  my ( $self, $pars ) = @_;

  my $html = sprintf qq(\n<div class="panel">);
  $html .= sprintf qq(\n  <h3 class="plain">%s</h3>), $pars->{'title'} if exists $pars->{'title'};
  $html .= $pars->{'html'} if exists $pars->{'html'};
  $html .= sprintf qq(\n  <p class="more"><a href="%s" rel="external-img"><img src="/core/gfx/blank.gif" alt="More" /></a></p>),
    encode_entities( $pars->{'link'} )
    if exists $pars->{'link'};
  $html .= qq(\n</div>);
  return $html;
}

## Output buffering code!
sub reset_output {
  my $self = shift;
  $self->{'_output'} = [];
  return $self;
}

sub push_output {
  my( $self, @html ) = @_;
  push @{$self->{'_output'}}, @html;
  return $self;
}

sub unshift_output {
  my( $self, @html ) = @_;
  unshift @{$self->{'_output'}}, @html;
  return $self;
}

sub get_output {
  my $self = shift;
  return join q(), @{$self->{'_output'}};
}

## Diagnostic event timer code!
sub init_events {
  my $self = shift;
  $self->{'_events'} = [];
  $self->{'_start'}  = time;
  return $self;
}

sub push_event {
  my ( $self, $caption, $level ) = @_;
  $level ||= 0;
  push @{$self->{'_events'}}, {( 'caption' => $caption, 'level' => $level, 'time' => time - $self->{'_start'} )};
  return $self;
}

sub dump_events {
  my $self = shift;
  $self->push_event( 'DUMP' );
  my $merged_txt = q();
  my $prev = 0;
  foreach ( @{$self->{'_events'}} ) {
    $merged_txt .= sprintf "%8.4f : %8.4f : %s\n", $_->{'time'}, $_->{'time'}-$prev, $_->{'caption'};
    $prev = $_->{'time'};
  }
  $self->push_message( $merged_txt, 'info', 1 );
  return $self;
}

sub table {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::Table->new( $self->r, @pars );
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

sub twocol {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::TwoCol->new( @pars );
}

sub tabs {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::Tabs->new( @pars );
}

sub is_xhr {
  my $self = shift;
  my $xhr_header = $self->r->headers_in->get('X-Requested-With') || q();
  return 1 if $xhr_header eq 'XMLHttpRequest' || $self->param('_xhr_');
  return;
}

1;
