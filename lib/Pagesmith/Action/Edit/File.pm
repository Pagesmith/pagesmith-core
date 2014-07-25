package Pagesmith::Action::Edit::File;

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
use Date::Format qw(time2str);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Spec;
use HTML::HeadParser;    ## Used to parse the HTML header
use Image::Size qw(imgsize);

use Const::Fast qw(const);
const my $TIME_FMT => '%a, %d %b %Y %H:%M %Z';
#----------------------------------------------------------

sub no_permission_error {
  my $self = shift;
  return $self->text->print('<p>No permission</p>')->ok;
}

sub run {
  my $self = shift;
  return $self->no_permission_error unless $self->site_is_editable;  ## Edit is not enabled!
  return $self->no_permission_error unless $self->is_valid_user;     ## No valid user or user does not have permission to edit!
  my $root = $self->r->document_root;
  (my $path  = $self->param('dir')||q() )=~ s{\A/}{}mxs;

  my $full_path = realpath( File::Spec->rel2abs( $path, $root ) );

  return $self->not_found unless -e $full_path;    ## Check exists and database
  return $self->forbidden unless substr( $full_path, 0, length $root ) eq $root; ## Not in tree!
  ## We need to do some file permission checking here!
  my $repos_details = $self->get_repos_details( $full_path );
  return $self->no_permission_error unless $self->svn_config->set_repos(   $repos_details->{'root'} );            ## Not a valid repository
  return $self->no_permission_error unless $self->svn_config->set_user(    $self->user->ldap_id );                ## Not a valid user for this repository

  ## Now do the stating...
  my $stat={};
  @{$stat}{qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)} = stat $full_path;

  return -d $full_path
       ? $self->run_dir( $path, $full_path, $stat, $repos_details )
       : $self->run_file( $path, $full_path, $stat, $repos_details )
       ;
}

sub run_file {
  my ($self, $path, $full_path, $stat, $repos_details ) = @_;
  my ($ext) = $path =~ m{[.]([^.]+)\Z}mxs ? $1 : q();
  my $details = $self->get_type_details( $ext );

    ## Get author information so we can set it!
  ## no critic (LongChainsOfMethodCalls)
  $self->{'left_col'} = $self->twocol
    ->add_entry( 'File name',      q(/) . $self->encode($path)   )
    ->add_entry( 'File type',      $details->[1]                  )
    ->add_entry( 'File size',      sprintf '%d bytes', -s $full_path    )
    ->add_entry( 'Last modified',  time2str( $TIME_FMT, $stat->{'mtime'} ) );
  ## use critic
  $self->{'right_col'} = $self->twocol;

  my $cref = $self->can( 'extra_'.$details->[0] );
  my ($actions,$extra) = $cref
                       ? $self->$cref( $path, $full_path, $repos_details )
                       : $self->extra_other( $path, $full_path, $repos_details )
                       ;
  $actions ||= [];
  $extra   ||= q();

  $self->{'left_col'}->add_entry( 'Actions', join q( ), @{$actions} ) if @{$actions};

  $self->printf(q(<div class="col1">%s</div><div class="col2 extended-info">%s</div><div class="clear">%s</div>),
    $self->{'left_col'}->render, $self->{'right_col'}->render,$extra );
  return $self->ok;
}

sub upload_form {
  my ( $self, $path, $title ) = @_;
  $title = 'Upload' unless defined $title;
  ## no critic (LongChainsOfMethodCalls)
  my $form = $self->stub_form
    ->add_class(          'form',     'check' )
    ->add_class(          'form',     'cancel_quietly' )
    ->set_option(         'no_reset' );
  ## use critic
  $form->set_url( '/action/Edit_Upload' );
  $form->add_stage( 'input' );
  $form->add_section( $title );
  $form->add('Hidden','path')->set_default_value( $path );
  return $form;
}

sub run_dir {
  my ( $self, $path, $full_path, $stat, $repos_details ) = @_;

  my $two_col_left = $self->twocol
    ->add_entry( 'File name',      q(/) . $self->encode($path)   )
    ->add_entry( 'File type',      'Directory' );

  my $two_col_right = $self->twocol
    ->add_entry( 'Last modified',  time2str( $TIME_FMT, $stat->{'mtime'} ) );

  ## no critic (LongChainsOfMethodCalls)
  my $tabs = $self->tabs
    ->add_tab( 't_list', 'Directory listing',
      sprintf '<div class="ajax" title="/component/Edit_DirectoryList?pars=%s"><p class="ajaxwait">Loading listing</p></div>', $self->encode( $path ) )
   ->add_tab( 't_history', 'History', sprintf
      '<div class="ajax" title="/component/Edit_History?pars=%s"><p class="ajaxwait">Loading logs</p></div>', $self->encode($path) )
   ->add_tab( 't_edits', 'Edits', sprintf
      '<div class="ajax" title="/component/Edit_Diff?pars=%s"><p class="ajaxwait">Loading diffs</p></div>', $self->encode($path) );
  ## use critic
  if( $path =~ m{\A(?:.*/)?(gfx|assets)(?:/.*)?\Z}mxs || $path =~ m{\A(i)(?:/.*)?\Z}mxs ) {
    my $type = $1;
    if( $self->svn_config->can_perform( $repos_details->{'path'}, 'addfile' ) ) {
      my $form = $self->upload_form( $path );
      $form->add( 'File', 'file' )->add_accepted_group( $type eq 'assets' ? 'asset_upload' : 'img_upload' )->set_multiple;
      $form->add( 'Hidden', 'flag' )->set_default_value( 'update' )->set_multiple;
      $form->add_confirmation_stage;
      $tabs->add_tab( 't_upload', 'Upload files', $form->render );
    }
  }

  ## no critic (ImplicitNewlines)
  return $self->printf(
    q(<div class="col1">%s</div>
      <div class="col2 extended-info">%s</div><div class="clear">%s</div>),
    $two_col_left->render, $two_col_right->render, $tabs->render )->ok;
  ## use critic
}

sub extra_img {
  my( $self, $path, $full_path, $repos_details ) = @_;
  my ($w, $h) = imgsize($full_path);
  my $markup = q();
  unless( $w && $h ) {
    $self->{'right_col'}->add_entry( 'Image size', 'Unknown' );
  } else {
    $self->{'right_col'}->add_entry( 'Image size', sprintf ' (%d x %d)', $w, $h );
    $markup = sprintf q(<div class="clear scrollable vert-sizing {'padding':400}"><p><img src="/%s" alt="" style="height:%dpx; width:%dpx" /></p></div>),
      $path, $h, $w;
  }
  my @actions;
  ## Do we have permission to replace/delete
  if( $self->svn_config->can_perform( $repos_details->{'path'}, 'update' ) ) {
    my $form = $self->upload_form( $path );
    $form->add( 'File', 'file' )->add_accepted_group( 'img_upload' );
    $form->add( 'Hidden', 'flag' )->set_default_value( 'update' );
    $form->add_confirmation_stage;
    $self->dumper( $form );
    $markup = $form->render.$markup;
  }
  if( $self->svn_config->can_perform( $repos_details->{'path'}, 'addfile' ) ) {
    push @actions, sprintf '<a href="/action/Edit_Delete?path=%s">Delete</a>',
      $self->encode($path);
  }
  return (\@actions, $markup);
}

sub extra_asset {
  my( $self, $path, $full_path, $repos_details ) = @_;
  my @actions = ( sprintf q(<a href="/%s">View</a>), $self->encode( $path ) );
  ## Do we have permission to replace/delete
  my $markup = q();
  if( $self->svn_config->can_perform( $repos_details->{'path'}, 'update' ) ) {
    my $form = $self->upload_form( $path );
    $form->add( 'File', 'file' )->add_accepted_group( 'asset_upload' );
    $form->add( 'Hidden', 'flag' )->set_default_value( 'update' );
    $form->add_confirmation_stage;
    $markup = $form->render.$markup;
  }
  if( $self->svn_config->can_perform( $repos_details->{'path'}, 'addfile' ) ) {
    push @actions, sprintf '<a href="/action/Edit_Delete?path=%s">Delete</a>',
      $self->encode($path);
  }
  return (\@actions, $markup);
}

sub extra_inc {
  my( $self, $path, $full_path, $repos_details ) = @_;
  if( open my $fh, q(<), $full_path ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $x = <$fh>;
    close $fh; ##no critic (CheckedSyscalls CheckedClose)
    my $tabs = $self->tabs;
    my @actions;
    $tabs->add_tab( 't_view', 'Source', sprintf q(<div><pre>%s</pre></div>), $self->encode($x) );
    if( $self->svn_config->can_perform( $repos_details->{'path'}, 'update' ) ) {
      my $form = $self->upload_form( $path, 'Modify' );
      $form->add( 'Text',   'contents' )->set_default_value( $x );
      $form->add( 'Hidden', 'flag' )->set_default_value( 'update_inc' );
      $form->add_confirmation_stage;
      $tabs->add_tab( 't_edit', 'Edit', $form->render );
    }

    if( $self->svn_config->can_perform( $repos_details->{'path'}, 'addfile' ) ) {
      push @actions, sprintf '<a href="/action/Edit_Delete?path=%s">Delete</a>',
        $self->encode($path);
    }
    $tabs->add_tab( 't_history', 'History', sprintf
            '<div class="ajax" title="/component/Edit_History?pars=%s"><p class="ajaxwait">Loading history</p></div>', $self->encode($path) )
         ->add_tab( 't_edits', 'Edits', sprintf
            '<div class="ajax" title="/component/Edit_Diff?pars=%s"><p class="ajaxwait">Loading edits</p></div>', $self->encode($path) );
    return (\@actions, $tabs->render);
  }
  return;
}

sub extra_html {
  my( $self, $path, $full_path, $repos_details ) = @_;
  return $self->extra_inc( $path, $full_path, $repos_details ) if $path =~ m{[.]inc\Z}mxs; ## This is an include file...!
  if( open my $fh, q(<), $full_path ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $x = <$fh>;
    close $fh; ##no critic (CheckedSyscalls CheckedClose)
    if ( $x =~ m{<head.*?>(.*?)</head>}mxs ) {
      (my $head = $1 ) =~ s{<%.*?%>}{}mxsg;
      my $head_parser = HTML::HeadParser->new();
      my $head_info   = $head_parser->parse($head);
      if( $head_info ) {
        my $t           = $head_info->header('Title');
        $self->{'right_col'}->add_entry( 'Title', $t ) if $t;
        foreach (qw(Author Keywords Description)) {
          my $tvar = $head_info->header("X-Meta-$_");
          $self->{'right_col'}->add_entry( $_, $tvar ) if $tvar;
        }
      }
    }
    my @actions;
    if( $self->svn_config->can_perform( $repos_details->{'path'}, 'update' ) ) {
      push @actions, sprintf '<a href="/action/Edit_Edit/%s">Edit</a>', $self->encode($path);
    }

    if( $self->svn_config->can_perform( $repos_details->{'path'}, 'addfile' ) ) {
      push @actions, sprintf '<a href="/action/Edit_Delete?path=%s">Delete</a>', $self->encode($path);
    }
    my $tabs = $self->tabs;
    ## no critic (LongChainsOfMethodCalls ImplicitNewlines)
    $tabs->add_tab( 't_view', 'Page',
            q(<class="vert-sizing {'padding':400}" style="margin: 0 10px">
                <iframe style="border:1px solid #ccc;width:100%;height:100%" name="pg" id="pg"></iframe>
              </div>) )
         ->add_tab( 't_source', 'Source', sprintf
            '<div class="ajax" title="/component/Edit_Source?pars=%s"><p class="ajaxwait">Loading source</p></div>', $self->encode( $path ) )
         ->add_tab( 't_history', 'History', sprintf
            '<div class="ajax" title="/component/Edit_History?pars=%s"><p class="ajaxwait">Loading logs</p></div>', $self->encode($path) )
         ->add_tab( 't_edits', 'Edits', sprintf
            '<div class="ajax" title="/component/Edit_Diff?pars=%s"><p class="ajaxwait">Loading edits</p></div>', $self->encode($path) );
    ## use critic
    return ( \@actions, $tabs->render );
  }
  return;
}

sub extra_other {
  return;
}

1;
