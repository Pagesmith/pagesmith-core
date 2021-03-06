package Pagesmith::Component::User;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
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

use List::MoreUtils qw(any);

use base qw(Pagesmith::Component);
use HTML::Entities qw(encode_entities);

sub usage {
  my $self = shift;
  return {
    'parameters'  => q(realms),
    'description' => 'Displays user information panel if the user is logged in OR if the page is being viewed from a selected list of Realms a login link...',
    'notes'       => [],
  };
}

sub define_options {
  my $self = shift;
  return { 'code' => 'template', 'defn' => '=s', 'default' => 'default', 'description' => 'template to use' };
}

my $template_sets = {
  'default' => [
    '<div id="user">%s logged in <a class="btt no-img" href="/action/logout">Logout</a></div>',
    '<div id="user"><a class="btt no-img" href="/login">Login</a></div>',
  ],
  'span' => [
    '<span id="user">%s logged in <a href="/action/logout">logout</a></span>',
    '<span id="user"><a href="/login">Login</a></span>',
  ],
  'div' => [
    '<div id="user">%s logged in <a href="/action/logout">logout</a></div>',
    '<div id="user"><a href="/login">Login</a></div>',
  ],
  'raw' => [
    '%s logged in <a href="/action/logout">logout</a>',
    '<a href="/login">Login</a>',
  ],
};
sub execute {
  my $self = shift;
  my @realms = $self->pars;
  my $template = $self->option( 'template' );
  $template = 'default' unless exists $template_sets->{$template};
# No restriction so return!
  my $login_realm = 1;
  if( @realms ) {
    my $client_realms = $self->r->headers_in->get('ClientRealm');
    if( defined $client_realms ) {
      my %realms = map { ( $_, 1 ) } @realms;
      my @user_realms = split m{[,\s]+}mxs, $client_realms;
      $login_realm = 0 unless any { $realms{$_} } @user_realms;
    } else {
      $login_realm = 0;
    }
  }

  ## Initialise User session object!
  my $user_session = $self->page->user;
  $user_session->fetch if $user_session;
  return $login_realm ? $template_sets->{$template}[1] : q()
    unless $user_session && $user_session->fetch && $user_session->name;

  return sprintf $template_sets->{$template}[0], encode_entities( $user_session->name );
}

1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

