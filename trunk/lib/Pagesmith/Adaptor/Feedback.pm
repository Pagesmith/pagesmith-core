package Pagesmith::Adaptor::Feedback;

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

## Adaptor for comments database
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

use base qw(Pagesmith::BaseAdaptor);

use Pagesmith::Object::Feedback;

sub connection_pars {
  return 'feedback';
}

sub create {

#@param (self)
#@param (hashref)? Optional hashref of attributes
#@return (Sange::Web:;Object::Feedback)
## Create a new feedback object
  my( $self, @pars ) = @_;
  return Pagesmith::Object::Feedback->new( $self, @pars );
}

sub get {

#@param (self)
#@param (string) URL of page
#@return (Sange::Web:;Object::Feedback[])
## Return an array of feedback objects for the given page
  my ( $self, $page ) = @_;
  ##no critic (ImplicitNewlines)
  my $aref = $self->all_hash(
    'select created_at, created_by, comment, ip, useragent
       from pagecomment
      where url = ?
      order by created_at asc',
    $page,
  );
  ##use critic (ImplicitNewlines)
  return map {
    Pagesmith::Object::Feedback->new(
      $self, { 'page' => $page, %{$_} } )
  } @{$aref};
}

sub store {

#@param (self)
#@param (Sange::Web:;Object::Feedback) object to store
#@return (boolean) true if insert OK
## Store the feedback object in the database
  my ( $self, $feedback_obj ) = @_;
  unless ( $feedback_obj->created_at ) {
    $feedback_obj->created_at = $self->now;
  }
  ##no critic (ImplicitNewlines)
  return $self->query(
   'insert into pagecomment
                (created_at,created_by,comment,url,ip,useragent)
          values( ?,         ?,         ?,      ?,  ?, ?       )',
    $feedback_obj->created_at, $feedback_obj->created_by, $feedback_obj->comment, $feedback_obj->page,
    $feedback_obj->ip,         $feedback_obj->useragent );
  ##use critic (ImplicitNewlines)
}
1;
