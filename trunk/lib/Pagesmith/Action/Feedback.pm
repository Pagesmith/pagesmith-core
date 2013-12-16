package Pagesmith::Action::Feedback;

## Feedback code
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

use Pagesmith::Adaptor::Feedback;

sub run {
  my $self       = shift;
  my $page       = $self->param('URL');
  my $created_by = $self->param('email');
  my $comment    = $self->param('comment');
  if ( $page
    && $created_by
    && $created_by ne 'username/email'
    && $comment
    && $comment ne 'Enter comment here' ) {
    Pagesmith::Adaptor::Feedback->new->create( {
      'page'       => $page,
      'created_by' => $created_by,
      'comment'    => $comment,
      'ip'         => $self->r->headers_in->get('X-Forwarded-For') . q( ) . $self->remote_ip,
      'useragent'  => $self->r->headers_in->get('User-Agent'),
    } )->store;
    return $self->redirect($page);
  }
  return $self->no_content;
}

1;

