package Pagesmith::Action::Component;

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

## Action to handle AJAX component inclusion
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

use base qw(Pagesmith::Action);

use English qw(-no_match_vars $EVAL_ERROR);
use HTML::Entities qw(encode_entities);

use Pagesmith::ConfigHash qw(docroot can_cache is_developer);
use Pagesmith::Page;
use Pagesmith::Cache;
use Pagesmith::Core qw(clean_template_type);


sub run {
  my $self   = shift;

# Remove need to "::" in URLs... by splitting on "_" to separate the action out!
# Note cannot have a component with an underscore in the name!
  my $action = $self->safe_module_name( $self->next_path_info );

# Hide "Developer" components if not in a developer Realm
  return $self->forbidden if $action =~ m{\bDeveloper::}mxs && !is_developer( $self->r->headers_in->get('ClientRealm') );

  my $parameters = $self->param('pars');
  ## Get the "pars" parameter which includes the parameters in
  ## <% %> block of the page...
  my $module = "Pagesmith::Component::$action";

  my $return;
  if ( $self->dynamic_use($module) ) {
    my $full_uri = $self->r->headers_in->{'Referer'};
    ( my $uri = $full_uri||q() ) =~ s{[?].*\Z}{}mxs;
    my $accept_header = $self->r->headers_in->get('Accept')||q(xhtml+xhml);
       $accept_header = q(xhtml+xhml) if $accept_header eq q(*/*);
    my $component = $module->new( Pagesmith::Page->new( $self->r, {
      'type'          => $accept_header =~ m{xhtml[+]xml}mxs ? 'xhtml' : 'html',
      'filename'      => docroot() . $uri,
      'uri'           => $uri,
      'full_uri'      => $full_uri,
      'template_flag' => $self->r->headers_out->get('X-Pagesmith-Decor') || undef,
      'template_type' => clean_template_type( $self->r ),
    } ) );

    $component->parse_parameters($parameters);
    my $cache_key = $component->cache_key;
    if ( $cache_key && can_cache('components') ) {
      ## We cache the contents of the response...
      (my $action_key = $action)=~s{\W}{_}mxsg;
      my $ch = Pagesmith::Cache->new( 'component', "$action_key|$cache_key" );
      $return = $self->flush_cache('component') ? undef : $ch->get();
      unless ($return) {
        $return = eval { $component->execute; };
        if ($EVAL_ERROR) {
          warn __PACKAGE__ . " $action EXECUTION FAILED  ...", $EVAL_ERROR, "\n";
          $return = $self->error( $action, 'execute' );
        } else {
          $ch->set( $return, $component->cache_expiry );
        }
      }
    } else {
      $return = eval { $component->execute; };
      if ($EVAL_ERROR) {
        warn __PACKAGE__ . " $action EXECUTION FAILED  ...", $EVAL_ERROR, "\n";
        $return = $self->error( $action, 'execute' );
      }
    }
  } else {
    ( my $module_tweaked = $module ) =~ s{::}{/}mxgs;
    if( $self->dynamic_use_failure($module) =~ m{\ACan't\slocate\s$module_tweaked[.]pm\sin\s[@]INC}mxs ) {
      $return = $self->error( $action, 'locate' );
    } else {
      warn __PACKAGE__ . " $action COMPILATION FAILED...", $self->dynamic_use_failure($module), "\n";
      $return = $self->error( $action, 'compile' );
    }
  }
  return $self->html->print( $return )->ok;
}

sub error {
  my($self,$action,$flag) = @_;
  return sprintf '<span class="web-error">Component %s failed to %s</span>', encode_entities($action), $flag;
}

1;
