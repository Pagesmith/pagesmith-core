package Pagesmith::Action::Edit::Browser;

## Dumps raw HTML of the file to the browser (syntax highlighted)
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

# Modules used by the code!
use Cwd qw(realpath);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Spec;
use HTML::Entities qw(encode_entities);
use Syntax::Highlight::HTML;

sub run {
  my $self = shift;
  return $self->forbidden      unless $self->site_is_editable;
  return $self->login_required unless $self->user->logged_in;
  return $self->no_permission  unless $self->is_valid_user;

  ## We need to check the permissions on this site!
  my $repos_details = $self->get_repos_details( $self->r->document_root );
  return $self->no_permission unless exists $repos_details->{'root'};                            ## Couldn't get SVN details...
  return $self->no_permission unless $self->svn_config->set_repos(   $repos_details->{'root'} ); ## Not a valid repository
  return $self->no_permission unless $self->svn_config->set_user(    $self->user->ldap_id     ); ## Not a valid user for this repository

  ## no critic (ImplicitNewlines)
  return $self->wrap_rhs( 'File browser',
   '<div class="panel"><h2 class="make-wide">File browser</h2>
      <div id="jqfTop"></div>
    </div>',
   '<div class="panel"><h3>Browser</h3><div id="jqfTree" style="padding:0 5px"></div></div>',
  )->push_javascript_files( '/core/js/developer/jqueryfiletree.js' )
   ->push_css_files( '/core/css/beta/jqueryfiletree.css' )->ok;
  ## use critic
}
1;
