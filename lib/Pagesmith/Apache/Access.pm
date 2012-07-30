package Pagesmith::Apache::Access;

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

use Apache2::Const qw(FORBIDDEN OK);
use base qw(Exporter);

our @EXPORT_OK = qw(_handler);
our %EXPORT_TAGS = ('ALL' => \@EXPORT_OK);
use Pagesmith::Support;         ## To give access to user

## The following are required to get around a mod_perl "feature".
## Attaching access handler prevents response handler being attached.

use File::Spec;                 ## To correctly concatenate index.html onto file
use APR::Finfo ();              ## To set info about file..
use APR::Const qw(FINFO_NORM);  ## -- "" --
use Pagesmith::Apache::HTML;    ## To get "wrapper"...


sub handler {
  my $r = shift;
  return _handler( sub { my( $apache_r, $user ) = @_; return 1; }, $r );
}

sub _handler {
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
    $r->filename( File::Spec->catfile( $r->filename,'index.html' ) );
    $r->finfo(APR::Finfo::stat($r->filename, APR::Const::FINFO_NORM, $r->pool));               ##no critic (CallsToUnexportedSubs)
    $r->push_handlers( 'PerlResponseHandler', sub { Pagesmith::Apache::HTML::handler($r); } ); ##no critic (CallsToUnexportedSubs)
  }
  return OK;
}

1;
