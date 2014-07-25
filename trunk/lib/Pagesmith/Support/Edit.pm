package Pagesmith::Support::Edit;

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

use Cwd qw(realpath);
use Date::Format qw(time2str);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Spec;
use File::Basename qw(dirname);
use HTML::Entities qw(encode_entities);
use HTML::HeadParser;    ## Used to parse the HTML header
use Image::Size qw(imgsize);

use Const::Fast qw(const);
const my $TIME_FMT => '%a, %d %b %Y %H:%M %Z';

use base qw(Pagesmith::Root);
use Pagesmith::Core qw(user_info);

use Pagesmith::ConfigHash qw(server_root get_config is_developer);
use Pagesmith::Utils::SVN::Config;

#----------------------------------------------------------

my %ext_map = (
  'app'    => ['Application',          qw(bat com exe)],
  'code'   => ['Source code',          qw(afp afpa asp aspx c cfm cgi cpp h lasso vb xml)],
  'css'    => ['CSS',                  qw(css)],
  'db'     => ['Database',             qw(sql)],
  'doc'    => ['Microsoft Word',       qw(doc docx)],
  'film'   => ['Video',                qw(3gp avi mov mp4 mpg mpeg wmv)],
  'fla'    => ['Flash',                qw(fla swf)],
  'html'   => ['HTML',                 qw(htm html thtml whtml mhtml inc)],
  'img'    => ['Image',                qw(bmp gif jpg jpeg pcx png tif tiff)],
  'java'   => ['Java',                 qw(jar java)],
  'linux'  => ['Linux install',        qw(rpm deb)],
  'music'  => ['Audio',                qw(m4p mp3 ogg wav)],
  'pdf'    => ['Adobe Acrobat',        qw(pdf)],
  'php'    => ['PHP',                  qw(php)],
  'ppt'    => ['Microsoft powerpoint', qw(ppt)],
  'psd'    => ['Adobe Photoshop',      qw(psd)],
  'ruby'   => ['Ruby',                 qw(rb rbx rhtml)],
  'script' => ['Script',               qw(js pl py pm perl)],
  'txt'    => ['Text',                 qw(log txt text ini cfg)],
  'xls'    => ['Microsoft excel',      qw(xls xlsx)],
  'zip'    => ['Compressed',           qw(zip bz2 gz tar tgz)],
);

my %types;
my %types_desc = ( 'unknown' => 'Unknown file format' );
foreach my $k ( keys %ext_map ) {
  my ( $v, @Q ) = @{ $ext_map{$k} };
  $types_desc{$k} = $v;
  $types{$_} = $k foreach @Q;
}

sub get_type_details {
  my ($self, $extn ) = @_;
  my $type = exists $types{$extn} ? $types{$extn} : 'unknown';
  my $desc = $types_desc{$type};
  return [ $type, $desc ];
}

## Support for file permission stuff!
sub svn_config {
  my $self = shift;
  return $self->{'svn_config'} ||= Pagesmith::Utils::SVN::Config->new( server_root, 'web', 1 );
}

sub svn_cmd {
  my $self = shift;
  unless( exists $self->{'svn_cmd'} ) {
    my $ui = user_info();
    $self->{'svn_cmd'} = [ '/usr/bin/svn', '--config-option', "config:tunnels:ssh=ssh -i $ui->{'home'}/.ssh/pagesmith/svn-ssh" ];
  }
  return @{$self->{'svn_cmd'}};
}

sub edit_flag {
  my $self = shift;
  return $self->{'flag'} ||= (
    is_developer( $self->r->headers_in->get('ClientRealm') ) ? get_config( 'Editable' ) : undef
  ) || 'none';
}

sub site_is_editable {
  my $self = shift;
  return $self->edit_flag ne 'none';
}

sub is_valid_user {
  my $self = shift;
  my $u = $self->user;
  return unless $u &&
                $u->auth_method eq 'sanger_ldap' && ## Needs to be local ldap user!
                $u->ldap_id;                        ## need to make this non-sanger at some point!
  if( $self->edit_flag eq 'self' ) {                           ## Self edit mode!
    my $ui = user_info();
    return unless $ui &&
                  $u->ldap_id eq $ui->{'username'};
  }
  return unless $self->svn_config->is_valid_user( $u->ldap_id );
  return 1;
}

sub get_repos_details {
  my( $self, $filename, $info_results ) = @_;


  $info_results = $self->run_cmd( [$self->svn_cmd, qw(info --non-interactive),$filename] )
    unless defined $info_results;
  my $svn_info;
  my $svn_info_array;

  if($info_results->{'success'} ) {
    foreach( @{ $info_results->{'stdout'} }) {
      my($k,$v) = split m{:\s+}mxs, $_, 2 ;
      $svn_info->{$k} = $v;
      push @{ $svn_info_array }, [$k,$v];
    }
  }

  my $repos_url  = $svn_info->{'URL'};
  my $repos_root = $svn_info->{'Repository Root'};
  unless( defined $repos_url ) {
    my $dir = $filename;
    while( $dir ) {
      $dir = dirname( $dir );
      last if $dir eq q(/);
      my $dir_info_results = $self->run_cmd( [$self->svn_cmd,qw(info --non-interactive),$dir] );
      if($dir_info_results->{'success'} ) {
        foreach( @{ $dir_info_results->{'stdout'} }) {
          my($k,$v) = split m{:\s+}mxs, $_, 2 ;
          $repos_url  = $v if $k eq 'URL';
          $repos_root = $v if $k eq 'Repository Root';
        }
        last if $repos_root;
      }
    }
  }
  return { ('success' => 0 ) } unless $repos_root;

  my $repos_path = substr $repos_url, length $repos_root;

  if( $repos_path =~ m{\A/trunk(.*)\Z}mxs ) {
    return {(
      'info'      => $svn_info,
      'infarray'  => $svn_info_array,
      'url'       => $repos_url,
      'root'      => $repos_root,
      'path'      => $repos_path,
      'part'      => $1,
      'success'   => $info_results->{'success'}, ## The first request was a success/failure!
    )};
  } else {
    return; ## Not on trunk
  }
}

1;
