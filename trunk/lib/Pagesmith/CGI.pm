package Pagesmith::CGI;

#### Author         : js5
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

use base qw(CGI);

use Crypt::CBC;
use Digest::MD5 qw(md5_hex);
use English qw(-no_match_vars $PID);
use HTML::Entities qw(encode_entities);
use JSON::XS;
use MIME::Base64 qw(encode_base64);

use Const::Fast qw(const);
const my $ERROR_WIDTH         => 160;
const my $STACKTRACE_MAXDEPTH => 10;

use Pagesmith::Message;

my $messages    = [];
my $html_output;
my $cgi_capture = 0;

sub new {
  my( $class, @param ) = @_;

  my $self = $class->SUPER::new(@param);

  return $self if exists $ENV{'MOD_PERL'}; ## Don't want to do this for mod_perl instances we are already capturing the stuff correctly anyway!

  $cgi_capture++; ## not mod_perl! - count the captures - we are only going to dump on the last one!
  return $self if defined $SIG{'__WARN__'}; ## Only attach once!

  $html_output = 0 unless defined $html_output;
  $messages    ||=[]; ## Initialize the messages hash!
  ## no critic(LocalizedPunctuationVars)
  $SIG{'__WARN__'} = sub {
    push @{$messages}, Pagesmith::Message->new( "CGI-BIN ERROR: @_",'warn' );
  };
  ## use critic
  return $self;
}

sub header {
  my( $self, @param ) = @_;
  $html_output = 1 if $param[0] =~ m{\b(text/html|application/xhtml[+]xml)\b}mxs;
  return $self->SUPER::header(@param);
}

sub DESTROY {
  my $self = shift;
  $self->SUPER::DESTROY();
  return unless $cgi_capture; ## We are not capturing via CGI but via mod_perl!
  $cgi_capture--;
  return if $cgi_capture;     ## Only want to return IF this is the last of a nested set of opens!
  undef $SIG{'__WARN__'};       ## Remove the warning handle!

  my $line = q(-) x $ERROR_WIDTH;
  return unless @{$messages};

  if( $html_output ) {
    my $non_object_data = [];
    foreach my $m (@{$messages}) {
      push @{ $non_object_data }, { map { $_=>$m->{$_} } keys %{$m} };
    }
    my $out = JSON::XS->new->encode( $non_object_data );
    ## no critic (InterpolationOfMetachars)
    my $cipher = Crypt::CBC->new(
      '-key'    => 'Ru4Aridh0$c4rKur71$5m1?#',
      '-cipher' => 'Blowfish',
      '-header' => 'randomiv', ## Make this compatible with PHP Crypt::CBC
    );
    ## use critic
    ( my $encrypted_errors = encode_base64( $cipher->encrypt( $out ) ) ) =~ s{\s}{}mxgs; ## Remove whitespace
    printf '<!-- ERRORS %s -->', $encrypted_errors;
  } else {
## No HTML output - so we are going to dump the errors to the log file anyway - but nicely merged together!
    printf {*STDERR} qq(\n\n%s\nPID %s; Request %s?%s; IP: %s\n),
      $line,
      $PID,
      exists $ENV{'REQUEST_URI'}  ? $ENV{'REQUEST_URI'}  : q(-),
      exists $ENV{'QUERY_STRING'} ? $ENV{'QUERY_STRING'} : q(-),
      exists $ENV{'REMOTE_ADDR'}  ? $ENV{'REMOTE_ADDR'}  : q(-);
    foreach( @{$messages} ) {
      printf {*STDERR} qq(%s\n%s\n), $line, join "\n",$_->render_txt($STACKTRACE_MAXDEPTH);
    }
    printf {*STDERR} qq(%s\n\n), $line;
  }
  $messages = [];
  return;
}

1;

__END__

h3. Description

Wrapper around CGI, which allows for some additional functionality, using
CGI in the "model" case
