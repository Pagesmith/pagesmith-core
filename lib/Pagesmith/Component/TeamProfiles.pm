package Pagesmith::Component::TeamProfiles;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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

##
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

use Const::Fast qw(const);
use Net::LDAP;
const my $PARAMS_PER_THESES => 4;

use base qw(Pagesmith::Component);

use Cwd qw(cwd realpath);
use File::Basename;
use File::Spec;
use HTML::Entities qw(encode_entities);
use POSIX qw(ceil);
use Time::HiRes qw(time);
use utf8;

use Pagesmith::Adaptor::Generic::Profile;

sub usage {
  my $self = shift;
  return {
    'parameters'  => q({team-{teamcode}|edit-{formcode}|username}+),
    'description' => 'Displays an individual or teams profile entry',
    'notes'       => [ 'NEED TO CONVERT TO USE Tabs/Twocol' ],
  };
}

sub define_options {
  my $self = shift;
  return (
    $self->ajax_option,
    {'code' => 'prefix', 'defn' => '=s', 'default' => 'team', 'description' => 'Team code' },
    {'code' => 'extra',  'defn' => '=s', 'default' => q(),    'description' => 'Extra file' },
  );
}

sub ajax {
  my $self = shift;
  return $self->default_ajax;
}

sub _format {
  my( $self, $string ) = @_;
  my $html = join "\n",
    map {sprintf '<p>%s</p>', encode_entities( $_ ) }
    grep { $_ }
    map { m{\A\s*(.*?)\s*\Z}mxs ? $1 : $_ }
    split m{\n\s*\n}mxs, $string;
  return $html ? $html : '<p>&nbsp;</p>';
}

sub _email {
  my( $self, $profile ) = @_;
  return q(-) unless lc($profile->get_email_flag) eq 'true';
  return $self->safe_email( $profile->get_email );
}

sub execute {
  my $self = shift;
  my $adaptor = Pagesmith::Adaptor::Generic::Profile->new();

  my @ids = $self->pars();

  my $prefix  = $self->option( 'prefix', 'team' );

  my @people;
  my @profiles;
  foreach my $id ( sort @ids ) {
    if( $id =~ m{\Ateam-(.*)\Z}mxs ) {
      push @profiles, @{$adaptor->get_all( $1 )};
    } elsif( $id =~ m{\Aedit-(.*)\Z}mxs ) {
      my $fo = $self->form_by_code( $1 );
      $fo->update_object;
      push @profiles, $fo->object;
    } else {
      my $profile = $adaptor->get( $id );
      push @profiles, $profile if $profile;
    }
  }
  foreach my $profile ( sort { $a->surname cmp $b->surname || $a->givenname cmp $b->givenname } @profiles ) {
    my $nav = sprintf qq(\n      <li><a href="#sub_%s_%s">%s</a></li>),
      $prefix, $profile->get_username, encode_entities( $profile->get_display );
    ## no critic (ImplicitNewlines)
    my $email_block = q();
    $email_block = sprintf '<span>%s</span>', $self->safe_email( $profile->get_email )
      if lc($profile->get_email_flag) eq 'true';
    my $idx = sprintf '
      <dt><a class="change-tab" href="#sub_%s_%s">%s</a></dt>
      <dd class="position">%s%s</dd>',
      $prefix, $profile->get_username,
      encode_entities( $profile->get_display ),
      $email_block,
      encode_entities( $profile->get_visible_job_title || $profile->get_job_title );

    my $ref_block = q();
    $ref_block = sprintf '
        <h4>References</h4>
        <%% References -full -collapse closed %s %%>', join q( ), @{ $profile->get_references || [] } if  @{ $profile->get_references||[] };

    my $entry = sprintf '
      <div id="sub_%s_%s">
        <h3>%s</h3>
        <h4 class="position"><span>%s</span> %s</h4>
        %s
        <h4>Research</h4>
        %s%s
      </div>', $prefix, $profile->get_username, encode_entities( $profile->get_display ),
        $self->_email( $profile ), encode_entities( $profile->get_visible_job_title || $profile->get_job_title ),
        $self->_format( $profile->get_biography ),
        $self->_format( $profile->get_research ),
        $ref_block;
    ## use critic
    push @people, {
      'nav'   => $nav,
      'index' => $idx,
      'entry' => $entry,
      'order' => $profile->get_surname.q( ).$profile->get_givenname  }
  }
  @people = sort { $a->{'order'} cmp $b->{'order'} } @people;
  my $nav = join q(), map {$_->{'nav'}} @people;
  my $ent = join q(), map {$_->{'entry'}} @people;
  my $idx = join q(), map {$_->{'index'}} @people;

  return q(<p>No team members listed</p>) unless $nav;
    ## no critic (ImplicitNewlines)
    return sprintf '
  <h3>Team members</h3>
  <div class="sub_nav profiles"><h3>Members</h3>
    <ul class="fake-tabs">
      <li><a href="#sub_%s_index">Team list</a></li>%s
    </ul>
  </div>
  <div class="sub_data profiles">
    <div id="sub_%s_index">
      <dl class="twocol evenwidth">%s
      </dl>%s
    </div>%s
  </div>', $prefix, $nav,
    $prefix,
    $idx,
    $self->option('extra')? '<% File '.$self->option('extra').' %>' : q(),
    $ent;
    ## use critic
}

1;

__END__

h3. Syntax

<% TeamProfiles
   -ajax
   teamcode
%>

h3. Purpose

Display the biographies of the team members

h3. Options

* ajax (optional) Whether to delay loading with AJAX

h3. Notes

h3. See also

* Generic object adaptor

h3. Examples

<% TeamProfiles -ajax webteam %>

h3. Developer notes

