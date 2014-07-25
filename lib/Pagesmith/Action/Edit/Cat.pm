package Pagesmith::Action::Edit::Cat;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

use Pagesmith::ConfigHash qw(docroot);
use Cwd qw(realpath);
use base qw(Pagesmith::Action Pagesmith::Support::Edit);

sub run {
  my $self = shift;

  return $self->no_content unless $self->site_is_editable;
  return $self->no_content unless $self->user->fetch;
  return $self->wrap( 'Unauthorised user', '<p>Your user does not have access to edit webpages</p>' )->ok
    unless $self->is_valid_user;

  $self->no_qr;  ## Just a few headers! don't create a QR graphic and don't include spelling on dev site!
  my $docroot = docroot;

  ## Grab information about the URL and the contents from the path.....
  my $url   = join q(/), grep { !m{\A[.]}mxs } $self->path_info; ## Remove '.' files!
  my $path  = realpath( join q(/), $docroot, $url );

  ## Check that the file exists.....
  return $self->no_content unless -e $path && ( -f $path || -d $path && -f ($path.='/index.html') ); ## no critic (Filetest_f)

  ## Check it is actually under docroot (call me paranoid!)
  $path =~ s{//+}{/}mxgs; ## Remove multiple q(/)s from path...
  return $self->no_content unless $docroot eq substr $path, 0, length $docroot;

  my $repos_details = $self->get_repos_details( $path );

  return $self->wrap( 'Non publishable directory', '<p>This area can not be maintained by web-interface</p>' )->ok
    unless $repos_details; ## Can't do anything unless in repository root!

  ## Set repository and user!
  return $self->wrap( 'Non publishable directory', '<p>This area can not be maintained by web-interface</p>' )->ok
    unless $self->svn_config->set_repos( $repos_details->{'root'} );   ## Not a valid repository

  my $revsion = $self->param( 'version' );

  my $content_res = $self->run_cmd( [ $self->svn_cmd, qw(cat -r), $self->param('r'), $path ] );

  return $self->html->print( join "\n", @{$content_res->{'stdout'}||[]} )->ok;
}

1;
