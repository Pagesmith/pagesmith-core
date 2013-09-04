package Pagesmith::Component::Edit::DirectoryList;

## Including a file!
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

use base qw(Pagesmith::Component Pagesmith::Support::Edit);

use Cwd qw(cwd realpath);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Basename qw(dirname);
use File::Spec;
use HTML::Entities qw(encode_entities);

use Const::Fast qw(const);
const my $DEFAULT_PAGE   => 25;
const my $UP_TO_DATE_COL => 8;
const my $FLAG_COLUMNS   => 10;

sub define_options {
  my $self = shift;
  return (
    $self->click_ajax_option,
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{dir}',
    'description' => 'Display table of file information for this directory',
    'notes'       => [],
  };
}

sub ajax {
  my $self = shift;
  return $self->click_ajax;
}

sub no_permission_error {
  return '<p>No permission</p>';
}
sub execute {
  my $self = shift;

  return $self->no_permission_error unless $self->site_is_editable;  ## Edit is not enabled!
  return $self->no_permission_error unless $self->is_valid_user;     ## No valid user or user does not have permission to edit!

  my $root = $self->r->document_root;
  ( my $path = $self->next_par||q() ) =~ s{\A/}{}mxs;
  my $full_path = realpath( File::Spec->rel2abs( $path, $root ) );

  $full_path .=q(/) unless $full_path =~ m{/\Z}mxs;
  return $self->no_permission_error unless -e $full_path;    ## Check exists and database
  return $self->no_permission_error unless -d $full_path;    ## Not a directory!
  return $self->no_permission_error unless substr( $full_path, 0, length $root ) eq $root; ## Not in tree!
  ## We need to do some file permission checking here!
  my $bin;
  return $self->no_permission_error unless opendir $bin, $full_path;    ## Die unless exists!!

  my $repos_details = $self->get_repos_details( $full_path );
  return $self->no_permission_error unless $self->svn_config->set_repos(   $repos_details->{'root'} );            ## Not a valid repository
  return $self->no_permission_error unless $self->svn_config->set_user(    $self->user->ldap_id );                ## Not a valid user for this repository

  my @dirlist = sort
                grep { ! m{\A[.]}mxs || m{(?:~|[.]bak)\Z}mxs }
                readdir $bin;
  closedir $bin;

  return '<p>No files</p>' unless @dirlist;

  my $files = $self->get_file_info( \@dirlist, $full_path, $path, $repos_details, $root );

  return $self->table
    ->make_sortable
    ->make_scrollable
    ->set_colfilter
    ->add_classes( 'before narrow-sorted  ' )
    ->set_export( [qw(txt csv xls)] )
    ->set_pagination( [qw(10 25 50 all)], $DEFAULT_PAGE )
    ->add_columns(
      { 'key' => 'name',       'caption' => 'File name', },
      { 'key' => 'type',       'caption' => 'File type', },
      { 'key' => 'last_mod',   'caption' => 'Last modified', 'format' => [['datetime','true','last_mod'],[q()]] },
      { 'key' => 'size',       'caption' => 'Size',          'format' => [ ['k','true','size'],[q()]],          'align' => 'r' },
      { 'key' => 'diff_dev',   'caption' => 'Local mods', 'filter_values' => [ qw(? ! ~ C M A D C* M* A* D*) ], 'align' => 'c' },
      { 'key' => 'diff_stage', 'caption' => 'Staging',    'filter_values' => [ qw(M A D) ],                     'align' => 'c' },
      { 'key' => 'diff_live',  'caption' => 'Live',       'filter_values' => [ qw(M A D) ],                     'align' => 'c' },
    )
    ->add_data( @{$files} )
    ->render;
}

sub get_files {
  my ($self, $dirlist, $full_path ) = @_;
  my @files = ([],[]);
  foreach my $file ( @{$dirlist} ) {
    my $stat={};
    @{$stat}{qw(dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks)} = stat "$full_path$file";
    if ( -d "$full_path$file" ) {
      push @{ $files[0] }, {
        'class'    => 'dir',
        'name'     => $file,
        'type'     => 'Directory',
        'last_mod' => $stat->{'mtime'},
      };
    } else {
      my ($ext) = $file =~ m{[.]([^.]+)\Z}mxs ? $1 : q();
      my $details = $self->get_type_details( $ext );
      push @{ $files[1] }, {
        'class'    => "ext_$details->[0]",
        'name'     => $file,
        'type'     => $details->[1],
        'last_mod' => $stat->{'mtime'},
        'size'     => $stat->{'size'},
      }
    }
  }

  return map { @{$_} } @files;
}

sub get_file_info {
  my( $self, $dirlist, $full_path, $path, $repos_details ) = @_;

  my $files      = $self->get_files( $dirlist, $full_path );
  my $root       = $self->r->document_root;
  my $repos_root = $repos_details->{'root'};
  my $url        = $repos_details->{'url'};
  my $part       = substr $url, length "$repos_root/trunk/";

  my $diffs = {};
  ### Deal with changes to local files....
  my $local_diffs = $self->run_cmd( [$self->svn_cmd, qw(st -uvN --non-interactive),$full_path] );
  foreach ( @{$local_diffs->{'stdout'}||[]} ) {
    next if m{\AStatus[ ]against[ ]revision}mxs;
    my $flag      = substr $_, 0, 1;
    my $uptodate  = substr $_, $UP_TO_DATE_COL, 1;
    my ($x,$rev,$prev_rev,$user,$p) = split m{\s+}mxs, substr $_, $FLAG_COLUMNS;
    $p = $rev if $flag eq q(?);
    $p = substr $p, 1+length $root;
    next if length $p <= length $path;
    my $name = substr $p, 1+length $path;
    $diffs->{$name}{'local'} = $flag if $flag ne q( );
    $diffs->{$name}{'local'}.=q(*) if $uptodate ne q( );
  }
  ## Now unstaged files...
  my %diff_commands = (
    'staging' => [ $self->svn_cmd, qw(diff --summarize -N --non-interactive),"$repos_root/staging/$part",$url],
    'live'    => [ $self->svn_cmd, qw(diff --summarize -N --non-interactive),"$repos_root/live/$part","$repos_root/staging/$part"],
  );
  foreach my $k ( keys %diff_commands ) {
    my $diff_output = $self->run_cmd( [$self->svn_cmd, qw(diff --summarize -N --non-interactive),"$repos_root/staging/$part",$url] );
    foreach ( @{$diff_output->{'stdout'}||[]} ) {
      my $name = substr $_, length "        $repos_root/$k/htdocs/$path/";
      my $flag = substr $_, 0, 1;
      $diffs->{$name}{$k} = $flag if $flag ne q( );
    }
  }

  ## Push these status changes back to the file list!
  foreach (@files) {
    my $k = $_->{'name'};
    next unless exists $diffs->{$k};
    $_->{'diff_dev'}   = $diffs->{$k}{'local'}  ||q();
    $_->{'diff_stage'} = $diffs->{$k}{'staging'}||q();
    $_->{'diff_live'}  = $diffs->{$k}{'live'}   ||q();
    delete $diffs->{$k};
  }

  ## Files which have an entry in the diffs - BUT are not in the local copy!!
  push @files, map {{
    'name'       => $_,
    'size'       => 0,
    'type'       => 'Missing',
    'diff_dev'   => $diffs->{$_}{'local'}||q(),
    'diff_stage' => $diffs->{$_}{'stage'}||q(),
    'diff_live'  => $diffs->{$_}{'live'}||q(),
  }} sort keys %{$diffs};

  return \@files;
}

1;

__END__

