package Pagesmith::Adaptor::Feedback;

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

use base qw(Pagesmith::Adaptor);

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
