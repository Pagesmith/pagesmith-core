package Pagesmith::Utils::Securecom;

## Crypt::CBC requests to a secure [Authentication] Server
## Author         : mw6
## Maintainer     : mw6
## Created        : 2012-01-05
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;
use Carp qw(carp croak);
use English qw(-no_match_vars);
use version qw(qv); our $VERSION = qv('0.1.0');

use Crypt::CBC; # qw decrypt encrypt
use LWP::UserAgent;
use HTTP::Request;

use Readonly qw(Readonly);

Readonly my $AGENT_NAME      => 'Pagesmith_Securecom/'; # This user agent (appears in apache log as requestor)
Readonly my $DEFAULT_TIMEOUT => 11; # LWP::UserAgent->timeout :  the timeout value in seconds. The default timeout() value is 180 seconds, i.e. 3 minutes.

use Pagesmith::Core qw(safe_base64_decode safe_base64_encode safe_md5 );
use Pagesmith::ConfigHash qw(get_config);
use base qw(Pagesmith::Action);

use Data::Dumper qw(Dumper);

sub new {
  my($class,$config) = @_;
  my $self    = {
    'id'           => $config->{'id'},
    'key'          => $config->{'key'},
    'api_key'      => $config->{'api_key'},
    'secret'       => $config->{'secret'},
    'methods'      => $config->{'methods'},
    'server'       => $config->{'AuthServer'} || get_config( 'AuthServer' ) ,
    'action'       => $config->{'action'},
    'AuthTimeout'  => $config->{'AuthTimeout'},
    'http_request' => $config->{'http_request'}, # for POST requests.
  };
  bless $self, $class;
  return $self;
}

sub cipher {
  my $self = shift;
  return $self->{'cipher'} ||= Crypt::CBC->new(
# CHECK THIS.
    '-key'     => $self->{'key'} || 'auth_token',
    '-cipher'  => 'Blowfish',
    '-header'  => 'randomiv', ## Make this compactible with PHP Crypt::CBC
  );
  return $self;
}

sub decode {
  my ($self,$content) = @_;
  return eval { $self->json_decode( $self->cipher->decrypt( safe_base64_decode( $content ) ) ) } || q();
}

sub encode {
  my ($self,$plainhash) = @_;
  my $encoded_object =  eval { safe_base64_encode( $self->cipher->encrypt( $self->json_encode( $plainhash ) ) ) };
  $encoded_object =~ s/\n//sxmg;
  return $encoded_object;
}

# Create the request (by encrypting the question) and decode the response as a plain hashref
sub request {
  my ( $self, $encoded_request ) = @_;
  # print STDERR "REQUEST CALLED ... ".Dumper( $encoded_request );
#safe_base64_encode(i $self->cipher->encrypt( $self->json_encode( $object )));
  my $rv = eval {
    my $res = $self->lwp_get( $encoded_request );
    return $res->content;
    # need to call $securecomm->decode( $securecomm->request())
  } || q();
  return $rv;
}

# do http 'GET' for url and return LWP::UserAgent->request as an HTTP::Response object
sub lwp_get {
  my ( $self,$encoded_request ) = @_;

  my $res = eval {
    my $req;
    if ( $self->{'http_request'} && $self->{'http_request'} =~ /^POST/ixms ) {
      # print {*STDERR} " HERE WE DID A POST \n";
      $req = HTTP::Request->new('POST' => $self->{'server'}.q(/).$self->{'action'}.q(/), [ 'data' => $self->{'api_key'}.q(/).$encoded_request ]) ;
    } else {
      # print {*STDERR} " HERE WE DID A GET \n";
      $req = HTTP::Request->new('GET' => $self->{'server'}.q(/).$self->{'action'}.q(/).$self->{'api_key'}.q(/).$encoded_request);
    }
    $req->content_type('application/x-www-form-urlencoded');
    $req->content();
    return LWP::UserAgent->new( '-agent'   => $AGENT_NAME.$VERSION,
                                '-timeout' => $self->{'AuthTimeout'} || $DEFAULT_TIMEOUT,
                               )->request( $req );
  } || q();
  # print {*STDERR} "LWP GET/POST CALLED: ".$self->{'server'}.q(/).$self->{'action'}.q(/).$self->{'api_key'}."/$encoded_request\n";
  print {*STDERR} $EVAL_ERROR if $EVAL_ERROR; ##no critic (checkedsyscalls)
  # print {*STDERR} Dumper($res);
  return $res;
}

1;
