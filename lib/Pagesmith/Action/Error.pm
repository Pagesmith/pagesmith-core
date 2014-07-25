package Pagesmith::Action::Error;

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

## Handles error messages
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

use base qw(Pagesmith::Action);

use Apache2::Const qw(HTTP_NOT_FOUND);
use HTML::Entities qw(encode_entities);

my $url_maps = {
  'exact_match' => {qw(
    /research/da1 /research/faculty/dadams/
    /research/th  /research/faculty/thubbard/
    /research/rd  /research/faculty/rdurbin/
    /resources/grc.html /research/areas/bioinformatics/grc/
    /resources/databases/encode/rgasp.html http://www.gencodegenes.org/rgasp/
  )},
  'path_match' => {qw(
    /research/fac /research/faculty/*
    /research/f   /research/faculty/
    /research/projects/genomedynamics /research/projects/genomicmutation/*
    /research    /research/
  )},
};

my $messages = {
  '400' => ['Bad Request',    'The syntax of your request has been so garbled that I have no idea how to respond to it'],
  '401' => ['Unauthorized',   'The request you made requires user authentication.'],
  '403' => ['Forbidden',      'The file you have requested cannot be served to you, the server has restricted access to it.'],
  '404' => ['File not found', 'We do not have anything on our server that matches the URI that you requested.'],
  '405' => [
    'Method not allowed',
    'The method specified in the Request-Line is not allowed for the resource identified by the Request-URI.' ],
  '410' => [
    'Gone',
    'The requested resource is no longer available on this server and there is no forwarding address. Please remove all references to this resource' ],
  '500' => [
    'Internal Server Error',
    'Unfortunately while trying to send you the contents that you requested, the server has hit a problem and cannot return what you have asked for.' ],
  '501' => ['Not Implemented', 'The server does not support the functionality required to fulfill the request.'],
  '503' => [
    'Service Unavailable',
    'The server is currently unable to handle the request due to a temporary overloading or maintenance of the server.' ],

## Fake 403 responses... for user account system...
  'no-permission' => [
    'No permission',
    'This is a restricted area of the website, your user does not have permission to see this resource.' ],
  'login-required' => [
    'Login required',
    'This is a restricted area of the website, you must <a href="/login">login</a> with your email address and password to view the content of these pages.' ],
};

sub run {
  my $self = shift;

  my $error_code = '999';
  my $msg_key;
  my $parsed_uri;

  ## Get information of the "previous request" if used as the error page this is an
  ## internal sub-request so need to use $r->prev to get the status code, pnotes
  ## and uri...

  if( $self->r->prev ) {
    my $flag = $self->r->prev->pnotes( 'do_not_throw_error_page' );
    if( $flag ) {  ## Do not throw any extra output!
      return;
    }
    $error_code = $self->r->prev->status;
    $msg_key    = $self->r->prev->pnotes( 'error-reason' );
    $parsed_uri = $self->r->prev->parsed_uri;
  } else {
    $parsed_uri = $self->r->parsed_uri;
  }
  my $page_url   = $parsed_uri->path;
  $self->set_navigation_path( $page_url );

  if( $msg_key && exists $messages->{$msg_key} ) {
    $self->wrap( $messages->{$msg_key}[0], sprintf '<p style="margin: auto 3em">%s</p>', $messages->{$msg_key}[1] );
    return;
  }

  if( $error_code == HTTP_NOT_FOUND ) { ## Handle 404 pages differently ... we will look up the page to see if it is redirectable!
    $page_url =~ s{/+$}{}mxs;
    if( exists $url_maps->{'exact_match'}{ $page_url } ) {
      return $self->redirect( $url_maps->{'exact_match'}{ $page_url } );
    } else {
      my $p = $page_url;
      my $remainder = q();
      while( $p ) {
        if( exists $url_maps->{'path_match'}{ $p } ) {
          my $t = $url_maps->{'path_match'}{ $p };
          if( $t =~ s{[*]$}{}mxs ) {
            return $self->redirect( "$t$remainder" );
          } else {
            return $self->redirect( "$t" );
          }
        }
        $p =~ s{(/[^/]*$)}{}mxs;
        $remainder = "$1$remainder";
      }
    }
  }

  my ( $error_caption, $error_message ) = exists $messages->{$error_code} ? @{ $messages->{$error_code} }
                                        : ( 'Unknown error', 'An error occurred' )
                                        ;
  my $line = sprintf '%s (%03d)', $error_caption, $error_code;
  ##no critic (ImplicitNewlines)
  $self->wrap(
    $line,
    sprintf '
<p>
  Your request for "%s" failed. The reason is:
</p>
<p style="margin: auto 3em">
  %s
</p>', encode_entities($page_url), $error_message );
  ##use critic
  return;
}

1;
