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
use Getopt::Long qw(GetOptionsFromString :config permute);

use Pagesmith::Core qw(safe_md5);
use Pagesmith::HTML::Table;
use Pagesmith::Form::Stub;
use Pagesmith::HTML::Tabs;
use Pagesmith::HTML::TwoCol;
use Pagesmith::Utils::FormObjectCreator;

#@property (Pagesmith::Page) _page Page object.
#@property (arrayref{}) _options Hashref of arrayrefs containing options passed in <% %>
#@property (string[]) _pars Array of parameters passed inside the <% %> tags

sub usage {
  return {
    'parameters' => 'unknown',
    'description' => 'unknown',
    'notes' => [ 'No documentation has been written for this component' ],
  };
}

## NO DEFINED OPTIONS
sub define_options {
  return;
}

sub type {
  my $self = shift;
  unless( exists $self->{'_component_type'} ) {
    ( $self->{'_component_type'} = ref $self ) =~ s{\APagesmith::Component::}{}mxs;
  }
  return $self->{'_component_type'};
}

sub ajax_option {
  return { 'code' => 'ajax', 'description' => 'Load component with AJAX if available' };
}

sub click_ajax_option {
  my $self = shift;
  return (
    $self->ajax_option,
    { 'code' => 'ajax-type', 'defn' => '=s', 'description' => 'Either no-cache and/or click to change behaviour of ajax action' },
  );
}

sub default_ajax {
  my $self = shift;
  return $self->option('ajax') ? 1 : 0;
}

sub click_ajax {
  my $self = shift;
  return $self->option('ajax') ? ( $self->option('ajax-type') || 1 ) : 0;
}

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
  return $self->trim( $x );
}

sub param {
  my ( $self, @param ) = @_;
  return $self->apr->param(@param);
}

sub trim_param {
  my ( $self, @param ) = @_;
  return $self->_trim( $self->apr->param(@param) );
}

sub parse {
  my( $self, $html ) = @_;
  ${$html} =~ s{<%\s+([[:upper:]][\w:]+)\s+(%>|(.*?)\s+%>)}{$self->page->execute( $1, $3 )}mxesg;

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
  my( $self, $flag ) = @_;
#@param (self)
#@return (HTML) HTML to display in AJAX placeholder
## This function is over-riden in the child module if required
  return $flag && $flag =~ m{click}mxs ? '<span class="click">Click to load content</span>' : 'Loading...';
}


sub cache_key {

#@param (self)
#@return (string|undef) flag to indicate whether or not this component can be cached, and if so the name of the key to use
## If the server does not cache components return undef, otherwise call the _cache_key function on the component itself

  my $self = shift;
  return unless $self->page->can_cache('components');
  return join '__', $self->my_cache_key();    ## Join the cache key / merge with double "_" signs...
}

sub my_cache_key {

#@param (self)
#@return (array) Array of strings defining the cache key.
## This function is over-riden in the child module if required
  my $self = shift;
  return $self->_cache_key;
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

sub option_scalar {
  my( $self, $key ) = @_;
  return unless exists $self->{'_options'}{$key};  ## Doesn't exist
  my $ret = $self->{'_options'}{$key};
  return $ret unless 'ARRAY' eq ref $ret;          ## Scalar so return it!
  return unless @{$ret};                           ## Empty arrayref so return nothing
  return $ret->[0];                                ## Return first element of array
}

sub option_arrayref {
  my( $self, $key ) = @_;
  return [] unless exists $self->{'_options'}{$key};  ## Doesn't exist so return empty array
  my $ret = $self->{'_options'}{$key};
  return $ret if 'ARRAY' eq ref $ret;                 ## Arrayref so return it
  return [$ret];                                      ## Scalar so wrap it in array ref!
}

sub par_part {
  my( $self, $idx ) = @_;
  return if $idx >= @{ $self->{'_pars'} };
  my $par  = $self->{'_pars'}[$idx];
  return $par->{'value'} if ref $par;
  return $par;
}

sub next_par {
#@param (self)
#return (scalar) first parameter
## accessor (read-only)
  my $self = shift;
  return unless @{ $self->{'_pars'} };
  my $par  = shift @{ $self->{'_pars'} };
  return $par->{'value'} if ref $par;
  return $par;
}

sub unshift_par {
  my( $self, $value ) = @_;
  unshift @{$self->{'_pars'}}, $value;
  return $self;
}

sub pars {
#@param (self)
#return (array) array of parameters
## accessor (read-only)
  my $self = shift;
  return map { ref $_ ? $_->{'value'} : $_ } @{ $self->{'_pars'} };
}

sub pars_hash {
#@param (self)
#return (array) array of parameters
## accessor (read-only)
  my $self = shift;
  return @{ $self->{'_pars'} };
}

sub next_par_hash {
#@param (self)
#return (scalar) first parameter
## accessor (read-only)
  my $self = shift;
  return shift @{ $self->{'_pars'} };
}

sub error {
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
  $pars ||= q();
  if( $self->can( 'define_options' ) ) {
    my @configuration = $self->define_options;
    my $options       = { map { ($_->{'code'} => $_->{'default'}||undef) } @configuration };
    my @get_opt_pars  = map { $_->{'code'}.($_->{'defn'}||q()) } @configuration;
    my $params        = [];
    my @interleave    = map { $_->{'interleave'} ? $_->{'code'} : () } @configuration;
    push @get_opt_pars, q(<>), sub { push @{$params}, { 'value' => $_[0]->name, map { $_ => $options->{$_} } @interleave }; } if @interleave;

    my( $res, $args, @warnings );
    my $rv = eval {
      local $SIG{'__WARN__'} = sub { push @warnings, @_; };
      ( $res, $args ) = GetOptionsFromString( decode_entities( $pars ), $options, @get_opt_pars );
    };
    if( @warnings ) {
      ## no critic (Carping)
      warn sprintf q(!raw!<p>The component:</p><blockquote>%s</blockquote><p>with parameters:</p><blockquote>%s</blockquote><p>returns the following warnings:</p><ul>%s</ul>),
        $self->my_name,
        $self->encode( $pars ),
        join q(), map { sprintf '<li>%s</li>', $self->encode( $_ ) } @warnings;
      ## use critic
    }
    push @{$params},
      map { @interleave ? { ('value' => $_, map { ($_ => $options->{$_}) } @interleave) } : $_ }
      @{$args} if $args && @{$args};
    $self->{'_options'} = $options;
    $self->{'_pars'}    = $params;
    return;
  }
  ## Fall back to old methos! ##
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
    } elsif ( $opt_flag && m{\A-(.*?)(?:=(.*))?\Z}mxs ) {
      push @{ $self->{'_options'}{$1} }, defined $2 && $2 ne q() ? $2 : 1;
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

  unless( exists $self->{'_options'}{$key} && defined $self->{'_options'}{$key} ) {
    return $default unless ref $default eq 'ARRAY';
    return wantarray ? @{$default} : $default->[0];
  }

  my @vals;
  if( defined $self->{'_options'}{$key} ) {
    if( ref $self->{'_options'}{$key} ) {
      @vals = @{ $self->{'_options'}{$key} };
    } else {
      @vals = ( $self->{'_options'}{$key} );
    }
  }
  return
      wantarray ? @vals
    : @vals     ? $vals[-1]
    :             undef;
}

sub qs {
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
  return $self->error( 'The component "' . encode_entities( ref $self ) . '" has not been created yet' );
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

sub table {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::Table->new( $self->r, @pars );
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
  return $self->fake_tabs->add_classes('hidden');
}

sub second_tabs {
  my( $self, @pars ) = @_;
  return $self->fake_tabs->add_classes('second-tabs')->set_option( 'no_heading', 1 );
}

sub is_xhr {
  my $self = shift;
  my $xhr_header = $self->r->headers_in->get('X-Requested-With') || q();
  return 1 if $xhr_header eq 'XMLHttpRequest' || $self->param('_xhr_');
  return;
}

sub my_name {
  my $self = shift;
  my($pagesmith,$component,@name_parts) = split m{::}mxs, ref $self;
  return join q(_), @name_parts;
}

1;
