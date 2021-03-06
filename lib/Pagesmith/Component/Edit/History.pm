package Pagesmith::Component::Edit::History;

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
use Date::Parse qw(str2time);

use Const::Fast qw(const);
const my $MAX          => 99;
const my $DEFAULT_PAGE => 25;

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

  return $self->no_permission_error unless -e $full_path;    ## Check exists and database
  return $self->no_permission_error unless substr( $full_path, 0, length $root ) eq $root; ## Not in tree!

  my $repos_details = $self->get_repos_details( $full_path );
  $self->dumper( $repos_details );
  return $self->no_permission_error unless $self->svn_config->set_repos(   $repos_details->{'root'} );            ## Not a valid repository
  return $self->no_permission_error unless $self->svn_config->set_user(    $self->user->ldap_id );                ## Not a valid user for this repository

  ## We need to do some file permission checking here!
  my $repos_root = $repos_details->{'root'};
  my $url        = $repos_details->{'url'};
  my $part       = substr $url, length "$repos_root/trunk/";
  my %cmds = (
    'trunk'   => [$self->svn_cmd, qw(log -l 100 --xml --stop-on-copy --non-interactive), $full_path],
    'staging' => [$self->svn_cmd, qw(log -l 100 --xml --stop-on-copy --non-interactive), "$repos_root/staging/$part"],
    'live'    => [$self->svn_cmd, qw(log -l 100 --xml --stop-on-copy --non-interactive), "$repos_root/live/$part"],
  );
  my %results;
  foreach my $type ( keys %cmds ) {
    my $result = $self->run_cmd( $cmds{$type} );
    my $details = join q(), @{$result->{'stdout'}};
    my @entries = split m{</logentry>}msx, $details;
    foreach (@entries) {
      my( $revision, $author, $date, $msg ) = m{revision="(\d+)"><author>(.*?)</author><date>(.*?)Z?</date><msg>(.*)</msg>}mxs; ## no critic(ComplexRegexes)
      next unless $revision;
      $results{$revision} ||= { 'revision' => $revision, 'author' => $author, 'date' => str2time($date), 'msg' => $msg };
      push @{ $results{$revision}{'type'}}, $type;
    }
  }

  my @entries = map { $results{$_} } reverse sort { $a <=> $b } keys %results;
  @entries = @entries[0..$MAX] if @entries > $MAX;
  $_->{'type'} = join q(, ), sort { $_ } @{$_->{'type'}} foreach @entries;
  return $self->table
    ->make_sortable
    ->make_scrollable
    ->set_colfilter
    ->add_classes( 'before narrow-sorted  ' )
    ->set_export( [qw(txt csv xls)] )
    ->set_pagination( [qw(10 25 50 all)], $DEFAULT_PAGE )
    ->add_columns(
      { 'key' => 'type',      'caption' => 'Branch', },
      { 'key' => 'revision',  'caption' => 'Revision', },
      { 'key' => 'author',    'caption' => 'Author', 'align' => 'c' },
      { 'key' => 'date',      'caption' => 'Size',   'format' => 'datetime' },
      { 'key' => 'msg',       'caption' => 'Message' },
    )
    ->add_data( @entries )
    ->render;
}

1;
