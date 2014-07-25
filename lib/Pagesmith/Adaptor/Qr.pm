package Pagesmith::Adaptor::Qr;

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

use Const::Fast qw(const);

const my $MAX_TRIES => 10;
const my $CODE_LEN  =>  8;

use Pagesmith::Object::Qr;
use Pagesmith::Config;
use DBI;

sub connection_pars {
  return 'objectstore';
}

## RO: Fr3y@

sub store {
  my ( $self, $entry, $flag ) = @_;

  $flag = 'insert' unless $entry->code;

  unless( $flag ) {
    my ($t) = $self->sv( 'select 1 from qr where code=?', $entry->code );
    $flag = $t ? 'update' : 'insert';
  }
  my ($now) = $self->now;
  if( $flag eq 'update'  ){
    ## no critic (ImplicitNewlines)
    return $self->query( '
      update qr
         set url = ?, prime = ?, updated_at = ?, updated_by = ?
       where code = ?',
      $entry->url, $entry->prime, $now, $entry->updated_by||q(), $entry->code,
    );
    ## use critic
  }
  my $tries_left = $entry->code ? 1 : $MAX_TRIES ;
  while( $tries_left-- ) {
    my $code = $entry->code || $self->random_code( $CODE_LEN );
    my $return = $self->query( 'insert ignore into qr (code, url, prime, created_at,created_by) values( ?,?,?,?,? )',
      $code, $entry->url, $entry->prime||'yes', $now, $entry->created_by||q(),
    );
    if( $return == 1 ) {
      $entry->set_code( $code );
      $self->query( 'update qr set prime = "no" where url = ? and code != ?', $entry->url, $code );
      return 1;
    }
  }
  return 0;
}

sub create {
#@param (self)
#@param (hashref)? Optional hashref of attributes
#@return Pagesmith::Object::Qr
## Create a new QRcode objec

  my( $self, @pars ) = @_;
  return Pagesmith::Object::Qr->new( $self, @pars );
}

sub get_by_url {
#@param (self)
#@param (string) URL of page
#@return (Pagesmith::Object::Qr)?
## Return the Qr code object related to this URL (if one exists)

  my ( $self, $url ) = @_;
  ##no critic (ImplicitNewlines)
  my $hashref = $self->row_hash(
    'select code, url, created_at, created_by, updated_at, prime
       from qr
      where url = ? order by prime desc
      limit 1',
    $url,
  );
  return unless $hashref;

  return Pagesmith::Object::Qr->new( $self, $hashref );
}

sub get_by_code {
#@param (self)
#@param (string) code
#@return (Pagesmith::Object::Qr)?
## Return the Qr code object related to the given "qr code"...

  my ( $self, $code ) = @_;
  ##no critic (ImplicitNewlines)
  my $hashref = $self->row_hash(
    'select code, url, created_at, created_by, updated_at, prime
       from qr
      where code = ?',
    $code,
  );
  return Pagesmith::Object::Qr->new( $self, $hashref ) if defined $hashref;
  return;
}

1;

