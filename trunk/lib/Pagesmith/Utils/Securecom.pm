package Pagesmith::Utils::Securecom;

#+----------------------------------------------------------------------
#| Copyright (c) 2014 Genome Research Ltd.
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
