package Pagesmith::Core;

## Library exporting common useful functions
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
const my $WIDTH => 78;

use base qw(Exporter);

use Apache2::Cookie;
use Carp qw(carp);
use URI::Escape qw(uri_unescape uri_escape_utf8);
use Digest::MD5 qw(md5_base64);    ## Used to get "hashed" name for CSS/JS files
use JSON::XS;
use MIME::Base64 qw(decode_base64 encode_base64);
use English qw(-no_match_vars $UID $EVAL_ERROR);

# This isn't an object so we will have to use Exporter to export
# functions...

our @EXPORT_OK = qw(full__warn fullescape safe_md5 parse_cookie clean_template_type safe_base64_encode safe_base64_decode user_info);
our %EXPORT_TAGS = ( 'ALL' => \@EXPORT_OK );

# At some point we should move these to the Apache config
# files for the server!

my $_json;
my %valid_templates = map { ( $_, $_ ) } qw(normal minimal);

## Wrapper around getpwuid to convert UID into user/name/uid/home directory!

sub user_info {
  my( $in_uid ) = @_;
  $in_uid = $UID unless defined $in_uid;
  my($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire) =
    $in_uid =~ m{\D}mxs ? getpwnam $in_uid : getpwuid $in_uid;
  my $user_info;
  if( $uid ) {
    $gcos =~ s{,.*}{}mxs; ## Removing trailing comments!
    $user_info = {
      'username'  => $name,
      'name'      => $gcos,
      'uid'       => $uid,
      'home'      => $dir,
    };
  } else {
    $user_info = {
      'username' => q(-),
      'name'     => q(-),
      'uid'      => 0,
      'home'     => q(-),
    };
  }
  return $user_info;
}

sub clean_template_type {
  my $r  = shift;
  my $tt = $r->headers_in->get('X-Pagesmith-TemplateType') ||q();
  return $valid_templates{$tt} || 'normal';
}

sub safe_base64_encode {
   my $string = shift;
   my $enc = encode_base64( $string );
   chomp $enc;
   $enc =~ s{[+]}{-}mxgs;
   $enc =~ s{/}{_}mxgs;
   return $enc;
}

sub safe_base64_decode {
   my $enc = shift;
   $enc =~ s{-}{+}mxgs;
   $enc =~ s{_}{/}mxgs;
   return decode_base64( $enc );
}

sub safe_md5 {
  my $string = shift;

#@param (string) String to base md5
## Get base64 string from filename...
## Tweak it by converting "+" -> "-" and "/" -> "_"
## so it is a safe filename for the file sytem!

  ( my $str = md5_base64($string) ) =~ s{[+]}{-}mxgs;
  $str =~ s{/}{_}mxgs;
  return $str;
}

sub full__warn {
  my $r = shift;
  my $flag = shift || 'out in env';

  printf {*STDERR} "%s\n", '<' x $WIDTH;
  printf {*STDERR} "URL: %s\n", $r->uri;
  printf {*STDERR} "CON: %s\n", $r->connection->id;

  if ( $flag =~ m{out}mxs ) {
    print {*STDERR} "\n"; ## no critic (CheckedSyscalls)
    $r->headers_out->do( sub { printf {*STDERR} "OUT: %30s => %s\n", @_; });
  }
  if ( $flag =~ m{in}mxs ) {
    print {*STDERR} "\n"; ## no critic (CheckedSyscalls)
    $r->headers_in->do( sub { printf {*STDERR} " IN: %30s => %s\n", @_; });
  }
  if ( $flag =~ m{env}mxs ) {
    print {*STDERR} "\n"; ## no critic (CheckedSyscalls)
    $r->subprocess_env->do( sub { printf {*STDERR} "ENV: %30s => %s\n", @_; });
  }
  printf {*STDERR} "%s\n", '>' x $WIDTH;
  return;
}

sub fullescape {
## Fully URL escape a string!
  my $string = shift;
  return uri_escape_utf8( $string, "0-\xffffffff" ); ## no critic (EscapedCharacters)
}

sub _json {
  return $_json ||= JSON::XS->new->utf8;
}

sub parse_cookie {
  my $r = shift;

  my $flags = {};
  my $cookie;
  my $rv = eval {
    my %cookie_jar = Apache2::Cookie->fetch( $r );
    $cookie = $cookie_jar{ 'Pagesmith' };
  };
  return $flags if $EVAL_ERROR;
  return $flags unless $cookie;

  if( $cookie ) {
  # We have to eval the from_json as this dies if the value of the cookie is not valid!
    eval { $flags = _json()->decode( $cookie->value ); }; ## no critic (CheckingReturnValueOfEval)
    # Not really worried about the eval error message as we can't do anything about a corrupt cookie
  }
  return $flags;
}

1;
