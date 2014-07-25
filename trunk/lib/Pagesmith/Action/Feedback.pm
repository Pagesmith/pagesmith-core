package Pagesmith::Action::Feedback;

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

