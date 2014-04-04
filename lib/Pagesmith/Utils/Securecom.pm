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

use LWP::UserAgent;
use HTTP::Request;

use Readonly qw(Readonly);

Readonly my $AGENT_NAME      => 'Pagesmith_Securecom/'; # This user agent (appears in apache log as requestor)
Readonly my $DEFAULT_TIMEOUT => 11; # LWP::UserAgent->timeout :  the timeout value in seconds. The default timeout() value is 180 seconds, i.e. 3 minutes.

use base qw(Pagesmith::Root Pagesmith::SecureSupport);

# do http 'GET' for url and return LWP::UserAgent->request as an HTTP::Response object
sub lwp_request {
  my ( $self, $encoded_request ) = @_;
  carp 'no request!' unless $encoded_request;
  # need to call $securecomm->decode( $securecomm->request())
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
  return $res->content if ($res && $res->content);
  return q();
}

1;
