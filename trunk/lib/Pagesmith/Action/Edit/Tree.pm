package Pagesmith::Action::Edit::Tree;
## Handles code for the File tree!
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

use base qw(Pagesmith::Action Pagesmith::Support::Edit);

use Cwd qw(realpath);
use File::Spec;
use HTML::Entities qw(encode_entities);
use HTML::HeadParser;    ## Used to parse the HTML header
use Image::Size qw(imgsize);

use Const::Fast qw(const);
const my $TIME_FMT => '%a, %d %b %Y %H:%M %Z';
#----------------------------------------------------------

sub no_permission_error {
  my $self = shift;
  return $self->print('<p>No permission to edit</p>')->forbidden;
}

sub run {
  my $self = shift;
  $self->text;
  return $self->no_permission_error unless $self->site_is_editable;  ## Edit is not enabled!
  return $self->no_permission_error unless $self->is_valid_user;     ## No valid user or user does not have permission to edit!

  my $root = $self->r->document_root;
  my $dir  = $self->trim_param('dir');
  $dir =~ s{\A/}{}mxs;
  if( $dir eq q() ) { ## This is the top level - so we may need to handle this differently!

  }
  my $full_dir = realpath( File::Spec->rel2abs( $dir, $root ) );

  return $self->no_permission_error unless -e $full_dir;    ## Check exists and database
  $dir = "$dir/" unless $dir =~ m{/\Z}mxs;
  $dir =~ s{\A/}{}mxs;
  $full_dir .= q(/);
  return $self->no_permission_error unless substr( $full_dir, 0, length $root ) eq $root;    ## Check it is in the specified directories
  my $bin;
  return $self->no_permission_error unless opendir $bin, $full_dir;    ## Die unless exists!!

## Now we need to check that we have permissions to see this repository!
  my $repos_details = $self->get_repos_details( $full_dir );
  return $self->no_permission_error unless $self->svn_config->set_repos(   $repos_details->{'root'} );   ## Not a valid repository
  return $self->no_permission_error unless $self->svn_config->set_user(    $self->user->ldap_id );       ## Not a valid user for this repository

  ## unless ( $self->config->can_perform( $repos_details->{'path'}, 'update' ) ) {
  ##   return $self->no_permission_error unless $dir;
  ##   return $self->print('<p>This is top level and we dont have permission to return all the directories we do have permission for!</p>')->ok;
  ## }*/

  ## Get files off the file system!
  my @dirlist = sort
              grep { ! m{\A[.]}mxs || m{(?:~|[.]bak)\Z}mxs }
              readdir $bin;
  closedir $bin;
  ## May need to svn here!
  return $self->print(q())->ok unless @dirlist;

  my @files = ( [], [] );
  foreach my $file ( @dirlist ) {
    if ( -d "$full_dir$file" ) {
      push @{ $files[0] }, ['dir coll', $file, 'Directory' ];
    } else {
      my ($ext) = $file =~ m{[.]([^.]+)\Z}mxs ? $1 : q();
      my $details = $self->get_type_details( $ext );
      push @{ $files[1] }, ["file ext_$details->[0]", $file, $details->[1] ];
    }
  }

  return $self->print(sprintf '<ul class="jft" style="display:none">%s</ul>',
    join q(),
    map {
      sprintf qq(\n  <li class="%s"><a href="#" title="%s" rel="%s">%s</a></li>),
        $_->[0], $_->[2], encode_entities("$dir$_->[1]"), encode_entities( $_->[1] )
    }
    grep { -e "$full_dir$_->[1]" }
    map { @{$_} } @files )->ok;
}

1;
