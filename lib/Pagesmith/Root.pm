package Pagesmith::Root;

## Base class to add common functionality!
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

Readonly my $DEFAULT_RANDOM_LENGTH => 4;
Readonly my $UUID64_LENGTH         => 22;
Readonly my $MAX_VIS_LENGTH        => 80;
Readonly my $DOFF                  => 1_900;

use Carp qw(cluck carp);
use Data::Dumper;
use Data::UUID;
use English qw(-no_match_vars $EVAL_ERROR $CHILD_ERROR);
use HTML::Entities qw(encode_entities);
use IPC::Run3 qw(run3);
use JSON::XS;
use Text::CSV::Encoded;
use POSIX qw(mktime ceil floor);
use Time::HiRes qw(time);
use MIME::Base64 qw(decode_base64 encode_base64);
use Pagesmith::Config;
use Pagesmith::Adaptor;

sub config {
  my( $self, $file, $config, $override ) = @_;
  return Pagesmith::Config->new( $file ) if ref $file eq 'HASH';

  $config   ||= 'site';
  $override ||= 0;
  return Pagesmith::Config->new( { 'file' => $file, 'config' => $config, 'override' => $override } );
}

my $failed_modules;

## empty constructor!

sub munge_date_time {
  my( $self, $val ) = @_;
  return q() unless $val;
  return $val =~ m{\A\d+\Z}mxs                                           ? $val
       : $val =~ m{\A(\d{4})-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)\Z}mxs  ? mktime($6,$5,$4,$3,$2-1,$1-$DOFF)
       : $val =~ m{\A(\d{4})-(\d\d)-(\d\d)\Z}mxs                         ? mktime(0,0,0,$3,$2-1,$1-$DOFF   )
       : $val =~ m{\A(\d\d):(\d\d):(\d\d)\Z}mxs                          ? mktime($3,$2,$1,0,0,0          )
       :                                                                  $val;
}

sub munge_date_time_array {
  my( $self, $val ) = @_;
  return q() unless $val;
  return $val =~ m{\A\d+\Z}mxs                                           ? gmtime $val
       : $val =~ m{\A(\d{4})-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)\Z}mxs  ? ($6,$5,$4,$3,$2-1,$1-$DOFF)
       : $val =~ m{\A(\d{4})-(\d\d)-(\d\d)\Z}mxs                         ? (0,0,0,$3,$2-1,$1-$DOFF   )
       : $val =~ m{\A(\d\d):(\d\d):(\d\d)\Z}mxs                          ? ($3,$2,$1,0,0,0          )
       :                                                                   gmtime $val;
}

sub commify {
  my( $self, $int ) = @_;
  $int =~ s{[^-.\d]}{}mxsg;
  1 while $int =~ s{\A(-?\d+)(\d{3})}{$1,$2}mxs;
  return $int;
}

sub new {
  my $class = shift;
  my $self  = {};
  bless $self, $class;
  return $self;
}

sub strip_html {
  my( $self, $str ) = @_;
  $str =~ s{<.*?>}{}mxgs;
  return $str;
}

sub encode {
#@param ($self)
#@param (string) $value - string to be encoded
#@return (string) HTML entity encoded version of $value;
  my ( $self, $value ) = @_;
  return encode_entities( $value );
}

sub _csv {
#@param ($self)
#@return (Text::CSV_XS)
## Lazy load CSV creation object
  my $self = shift;
  return $self->{'_csv'} ||= Text::CSV::Encoded->new({
    'encoding_out'  => 'iso-8859-1',
  });
}

sub _json {
#@param ($self)
#@return (JSON::XS)
## Lazy load JSON creation object
  my $self = shift;
  return $self->{'_json'} ||= JSON::XS->new->utf8->allow_nonref;
}

sub trim {
  my( $self, $string ) = @_;
  return $string =~ m{\A\s*(.*?)\s*\Z}mxs ? $1 : $string;
}

sub json_encode {
  my( $self, $perl_ref ) = @_;
  return $self->_json->encode( $perl_ref );
}

sub json_decode {
  my( $self, $scalar ) = @_;
  return unless $scalar;
  return $self->_json->decode( $scalar );
}

sub safe_bit {
  my( $self, $string ) = @_;
  $string =~ s{\W}{}mxgs;
  return $string;
}

sub safe_module_name {
  my( $self, $string ) = @_;
  return join q(::), map { ucfirst $self->safe_bit( $_ ) } split m{(?:_|::)}mxs, $string;
}

sub safe_uuid {
  my $self = shift;
  $self->{'uuid_gen'} ||= Data::UUID->new;
  ( my $t = $self->{'uuid_gen'}->create_b64() ) =~ s{\+}{-}mxgs;
  $t =~ s{/}{_}mxgs;
  return substr $t, 0, $UUID64_LENGTH;    ## Don't really need the two == signs at the end!
}

sub unpack_blob {
  my( $self, $string ) = @_;
  return $self->json_decode( decode_base64( $string ) );
}

sub pack_blob {
  my( $self, $blob ) = @_;
  return encode_base64( $self->json_encode( $blob ) );
}

sub random_code {

#@param (self)
#@param (int?) $length Length og string to generate
#@param chr*   @chars List of characters to use in string!
#@return (string) Random string of characters
  my $self          = shift;
  my $length        = shift || $DEFAULT_RANDOM_LENGTH;
  my $char_arrayref = shift;
  my @chars         = defined $char_arrayref && ref $char_arrayref eq 'ARRAY' ? @{$char_arrayref} : ( 'a' .. 'z', '0' .. '9' );
  return join q(), map { $chars[ floor(@chars * rand) ] } (1 .. $length);
}

sub dynamic_use {

#@param (self)
#@param (string) $classname Class name to use
#@return (boolean) 1 if module used successfully
## Equivalent of USE - but used at runtime
  my ( $self, $classname ) = @_;
  unless ($classname) {
    my @caller        = caller 0;
    my $error_message = "Dynamic use called from $caller[1] (line $caller[2]) with no classname parameter\n";
    carp $error_message;
    $failed_modules->{$classname} = $error_message;
    return 0;
  }
  if ( exists $failed_modules->{$classname} ) {

    #warn "Pagesmith::Root: tried to use $classname again - this has already failed $failed_modules->{$classname}";
    return 0;
  }
  my ( $parent_namespace, $module ) = $classname =~ m{\A(.*::)(.*)$}mxs ? ( $1, $2 ) : ( q(::), $classname );
  {
    ##no critic (NoStrict)
    no strict 'refs';
    return 1
      if $parent_namespace->{ $module . q(::) } && %{ $parent_namespace->{ $module . q(::) } || {} };    # return if already used
    ##use critic
  }
  my $return;
  {
##no critic (NoStrict)
    no strict 'refs';
    $return = eval "require $classname"; ##no critic (StringyEval)
##use critic
  }
  if ( $EVAL_ERROR || !$return ) {
    my $module_name = $classname;
    $module_name =~ s{::}{/}mxgs;
    cluck "Pagesmith::Root: failed to use $classname\nPagesmith::Root: $EVAL_ERROR" unless $EVAL_ERROR =~ m{\ACan't\slocate\s$module_name\.pm}mxs;

    $failed_modules->{$classname} = $EVAL_ERROR || 'Unknown failure when dynamically using module';
    return 0;
  }
  $classname->import();
  return 1;
}

sub dynamic_use_failure {
## Return error message cached if use previously failed!
  my ( $self, $classname ) = @_;
  return $failed_modules->{$classname};
}

sub _full_escape {
  my( $self, $string ) = @_;
  return q() unless $string;
  return join q(), map { sprintf '%%%02x', ord $_ } split m{}mxs, $string;
}

sub _full_encode {
  my( $self, $string ) = @_;
  return q() unless $string;
  return encode_entities( $string, q(^~) );
}

sub _safe_email {
  my( $self, $email, $name ) = @_;
  return q() unless $email;
  $name ||= $email;
  if ( $self->option('nolink') ) {
    return encode_entities( $name, q(^~) );
  }
  if( $email ne $name ) {
    return sprintf '<a href="mailto:%s">%s</a>',
      $self->_full_escape( "$name <$email>" ),
      $name =~ m{@}mxs ? $self->_full_encode( $name ) : encode_entities($name);
  } else {
    return sprintf '<a href="mailto:%s">%s</a>',
      $self->_full_escape( $email ),
      $self->_full_encode( $email );
  }
}

sub _dumper {
  my( $self, $data_to_dump, $name_of_data ) = @_;
  return Data::Dumper->new( [ $data_to_dump ], [ $name_of_data ] )->Sortkeys(1)->Indent(1)->Terse(1)->Dump();
}

sub pre_dumper {
  my( $self, $data_to_dump, $name_of_data ) = @_;
  return '<pre>'.encode_entities( $self->_dumper( $data_to_dump, $name_of_data )).'</pre>';
}

sub dumper {
  my( $self, $data_to_dump, $name_of_data ) = @_;
  $name_of_data ||= 'data';
  carp '!pre!', $self->_dumper( $data_to_dump, $name_of_data );
  return;
}

sub resplit {
  my( $self, $a_ref ) = @_;
  my @ret = map { split m{\r?\n}mxs, $_ } @{$a_ref};
  return \@ret;
}

sub run_cmd {
  my( $self, $command_ref, $input_ref ) = @_;
  $input_ref ||= [];
  my $out_ref   = [];
  my $err_ref   = [];
  my $ret = run3 $command_ref, $input_ref, $out_ref, $err_ref;
  return {(
    'command' => $command_ref,
    'success' => $ret && !$CHILD_ERROR,
    'error'   => $CHILD_ERROR,
    'stdout'  => $self->resplit( $out_ref ),
    'stderr'  => $self->resplit( $err_ref ),
  )};
}

sub get_adaptor {
  my( $self, $type, @params ) = @_;
  my $module = 'Pagesmith::Adaptor::'.$type;
  return $self->dynamic_use( $module ) ? $module->new( @params ) : undef;
}

sub get_adaptor_conn {
  my( $self, $conn, @params ) = @_;
  return Pagesmith::Adaptor->new( $conn );
}

sub _safe_link {
  my( $self, $url, $max_length, $extra ) = @_;
  $max_length ||= $MAX_VIS_LENGTH;
  $extra      ||= {};
  my $disp_text;
  if( $url =~ m{\A/}mxs ) {
    $url = $self->base_url.$url;
  }
  if(length( $url ) > $max_length && $url =~ m{(https?|ftp):\/\/([^/]+)/(.*)\Z}mxs ) {
    $disp_text = qq($1://$2/);
    my $other = $3;
    my $remaining = $max_length - length $disp_text;
    if( $remaining < 0 ) {
      $disp_text = sprintf '%s<span class="print-hide">...</span><span class="print-show">%s</span>', encode_entities( $disp_text ), encode_entities( $other );
    } else {
      my $show_first  = floor( $remaining / 2 );
      my $show_last   = ceil( $remaining / 2 );
      $disp_text = sprintf '%s%s<span class="print-hide">...</span><span class="print-show">%s</span>%s',
        encode_entities( $disp_text ),
        encode_entities( substr $other, 0, $show_first ),
        encode_entities( substr $other, $show_first, -$show_last ),
        encode_entities( substr $other, -$show_last );
    }
  } else {
    $disp_text = encode_entities( $url );
  }
  my $title = ! exists $extra->{'title'} ? $url : sprintf '%s (%s)', $extra->{'title'}, $url;
  if( exists $extra->{'template'} ) {
    my $t = { 'title' => $extra->{'title'}, 'url' => $disp_text };
    ($disp_text = $extra->{'template'} ) =~ s{%%(title|url)%%}{$t->{$1}}msexg;
  }
  return sprintf '<a title="%s" href="%s">%s</a>',  $title, encode_entities( $url ), $disp_text;
}

sub set_flush_cache {
  my( $self, $flush_cache ) = @_;
  $self->{'flush_cache'} = $flush_cache || q();
  return $self;
}

sub flush_cache {
  my( $self, $flag ) = @_;
  $self->{'flush_cache'} = q() unless exists $self->{'flush_cache'} && defined $self->{'flush_cache'};
  return 0 <= index $self->{'flush_cache'}, $flag;
}

sub set_base_url {
  my( $self, $base_url ) = @_;
  $self->{'_base_url'} = $base_url;
  return $self;
}

sub base_url {
  my $self = shift;
  return $self->{'_base_url'} || q(/);
}

1;
