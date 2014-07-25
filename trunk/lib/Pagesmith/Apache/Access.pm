package Pagesmith::Apache::Access;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
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

## Apache Access Handler for Cantrace archive: Deny access to people not in the Cantrace Archive Group.
## Author         : mw6
## Maintainer     : js5
## Created        : 2011-12-08
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use Carp qw(carp);
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Apache2::Const qw(FORBIDDEN OK DECLINED);
use base qw(Exporter);

our @EXPORT_OK = qw(my_handler);
our %EXPORT_TAGS = ('ALL' => \@EXPORT_OK);
use Pagesmith::Support;         ## To give access to user

## The following are required to get around a mod_perl "feature".
## Attaching access handler prevents response handler being attached.

use File::Spec;                 ## To correctly concatenate index.html onto file
use APR::Finfo ();              ## To set info about file..
use APR::Const qw(FINFO_NORM);  ## -- "" --
use Pagesmith::Apache::PushDir; ## To get "wrapper"...
use Pagesmith::Apache::HTML;    ## To get "wrapper"...


sub handler {
  my $r = shift;
  return my_handler( sub { my( $apache_r, $user ) = @_; return 1; }, $r );
}

sub my_handler {
  my( $permission_callback, $r ) = @_;
  my $root = Pagesmith::Support->new;
  my $user = $root->user( $r );

  $r->headers_out->add( 'Cache-Control', 'max-age=0, no-cache' );
  $r->headers_out->add( 'Pragma',        'no-cache' );

  unless( $user && $user->logged_in ) {
    $r->pnotes( 'error-reason', 'login-required' );
    return FORBIDDEN;
  }
  unless( &{$permission_callback}( $r, $user ) ) {
    $r->pnotes( 'error-reason', 'no-permission' );
    return FORBIDDEN;
  }
  if( -d $r->filename && -f File::Spec->catfile($r->filename,'index.html') ) { ## no critic (Filetest_f)
    if( $r->filename =~ m{/\Z}mxs ) {
      $r->filename( File::Spec->catfile( $r->filename,'index.html' ) );
      $r->finfo(APR::Finfo::stat($r->filename, APR::Const::FINFO_NORM, $r->pool));               ##no critic (CallsToUnexportedSubs)
      $r->push_handlers( 'PerlResponseHandler', sub { Pagesmith::Apache::HTML::handler($r); } ); ##no critic (CallsToUnexportedSubs)
    } else {
      $r->push_handlers( 'PerlResponseHandler', Pagesmith::Apache::PushDir::handler($r) );       ##no critic (CallsToUnexportedSubs)
    }
  }

  return OK;
}

1;
