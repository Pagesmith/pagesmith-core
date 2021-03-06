package Pagesmith::Component::Developer::Information;

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

use Const::Fast qw(const);
const my $MAX_DEPTH => 15;

use base qw(Pagesmith::Component);

use Apache2::ServerUtil;
use Apache2::URI;
use URI::Escape qw(uri_escape_utf8);
use English qw(-no_match_vars $PID $EVAL_ERROR);
use HTML::Entities qw(encode_entities);
use Sys::Hostname qw(hostname);

use Pagesmith::ConfigHash;

sub usage {
  return {
    'parameters'  => q(None),
    'description' => q(Full dump of information about the request and the server - environment, server settings, headers, parameters etc),
    'notes' => [],
  };
}

##no critic (ExcessComplexity)
sub execute {
#@param (self)
#@return (html) HTML output over server information
## Returns a chunk of HTML containing diagnostic information about the
## current web-request, including general information about the Apache
## process, the modules in memory, the include path, the environment
## variables, the HTTP headers and any attached apache notes.

  my $self = shift;
  my $r = $self->r;

  ##no critic (ImplicitNewlines)
my $ROW_T  = "\n    <dt>%s</dt>\n    <dd>%s</dd>";
my $LIST_T = "\n    <li>%s</li>";
  my $html = q(
  <div class="panel">
    <ul class="tabs">
      <li><a href="#t_uri">Parsed URI</a></li>
      <li><a href="#t_general">General</a></li>
      <li><a href="#t_env">Env</a></li>
      <li><a href="#t_dirc">Dir Config</a></li>
      <li><a href="#t_headers">Headers</a></li>
      <li><a href="#t_notes">Notes</a></li>
      <li><a href="#t_inc">Include path</a></li>
      <li><a href="#t_modules">Modules</a></li>
      <li><a href="#t_user">User</a></li>
    </ul>
    <div class="clear" style="height:700px;overflow:scroll">

<div id="t_uri">
  <h3 class="keep">Parsed URI</h3>
  <dl style="font-size: 80%" class="twocol">);
  foreach( qw(scheme user password hostname port path rpath query fragment) ) {
    my $ret = eval { sprintf $ROW_T, encode_entities( $_ ), $self->value( $r->parsed_uri->$_ ); };
    $html .= $EVAL_ERROR ? sprintf $ROW_T, encode_entities( $_ ), '###' : $ret;
  }
  $html .= q(
  </dl>
</div>

<div id="t_general">
  <h3 class="keep">General settings</h3>
  <dl style="font-size: 80%" class="twocol">);

  #-- Dump general information about the virtual server!
  my @host_info = gethostbyname hostname();
  my $host_name = @host_info ? $host_info[0] : q(--);
  my @Q = qw(
    args            bytes_sent      content_encoding    content_languages
    content_type    filename        header_only         hostname
    main            method          method_number       mtime
    next            no_local_copy   path_info           prev
    proto_num       protocol        request_time
    status          status_line     the_request         unparsed_uri
    uri             user
    as_string       default_type    document_root       get_limit_req_body
    get_server_name get_server_port is_initial_req      location
  );
  $html .= sprintf $ROW_T, 'Host', encode_entities( $host_name );
  $html .= sprintf $ROW_T, 'PID',  $PID;
  foreach( sort @Q ) {
    my $ret = eval { sprintf $ROW_T, encode_entities( $_ ), $self->value( $r->$_ ); };
    $html .= $EVAL_ERROR ? sprintf $ROW_T, encode_entities( $_ ), '###' : $ret;
  }
  $html .= q(
  </dl>

  <h3 class="keep">Server settings</h3>
  <dl style="font-size: 80%" class="twocol">);
  @Q = qw(
    error_fname is_virtual keep_alive keep_alive_max
    keep_alive_timeout limit_req_fields limit_req_fieldsize
    limit_req_line loglevel path port server_admin
    server_hostname timeout
  );
  foreach( sort @Q ) {
    my $ret = eval { sprintf $ROW_T, encode_entities( $_ ), $self->value( $r->server->$_ ); };
    $html .= $EVAL_ERROR ? sprintf $ROW_T, encode_entities( $_ ), '###' : $ret;
  }
  @Q = qw(
    get_server_built get_server_version get_server_description
    get_server_banner
    restart_count server_root user_id group_id
  );
  foreach( sort @Q ) {
    my $t = 'Apache2::ServerUtil::'.$_;
    my $ret = eval {
      no strict 'refs'; ##no critic (NoStrict)
      sprintf $ROW_T, encode_entities( $_ ), $self->value( &{$t} );
    };
    $html .= $EVAL_ERROR ? sprintf $ROW_T, encode_entities( $_ ), '###' : $ret;
  }

  #-- Dump the environment variables - before and after running subprocess_env

  $html .= q(
  </dl>
</div>

<div id="t_env">
  <h3 class="keep">%ENV (before running subprocess_env)</h3>
  <dl style="font-size: 80%" class="twocol">);
  foreach( sort keys %ENV ) {
    $html .= sprintf $ROW_T, encode_entities( $_ ), $self->env_var($_);
  }

  $r->subprocess_env();

  $html .= q(
  </dl>

  <h3 class="keep">%ENV (after running subprocess_env)</h3>
  <dl style="font-size: 80%" class="twocol">);
  foreach( sort keys %ENV ) {
    $html .= sprintf $ROW_T, encode_entities( $_ ), $self->env_var($_);
  }

  #-- Dump information stored in DirConfig directives
  $html .= q(
  </dl>
</div>

<div id="t_dirc">
  <h3 class="keep">Dir config</h3>
  <dl style="font-size: 80%" class="twocol">);
  my $X = $r->dir_config();
  my %t;
  while( my($K,$V) = each %{$X} ) {
    push @{$t{$K}}, sprintf $ROW_T, encode_entities( $K ), $self->value( $V );
  }
  foreach( sort keys %t ) {
    $html .= join q(), sort @{$t{$_}};
  }
  $html .= q(
  </dl>

  <h3 class="keep">Server configs</h3>
  <dl style="font-size: 80%" class="twocol">);
  # And the values of the Pagesmith varibles in the server config!
  $X = Pagesmith::ConfigHash::hash;
  foreach( sort keys %{$X} ) {
    $html .= sprintf $ROW_T, encode_entities( $_ ), $self->value( $X->{$_} );
  }

  #-- Dump the headers in
  $html .= q(
  </dl>
</div>

<div id="t_headers">
  <h3 class="keep">headers in</h3>
  <dl style="font-size: 80%" class="twocol">);
  $X = $r->headers_in();
  foreach( sort keys %{$X} ) {
    $html .= sprintf $ROW_T, encode_entities( $_ ), $self->value( $r->headers_in->{ $_ } );
  }

  #-- Dump the headers out (and error headers out if set!)
  $html .= q(
  </dl>
  <h3 class="keep">headers out</h3>);
  $X = $r->headers_out();
  if( keys %{$X} ) {
    $html .= '
  <dl style="font-size: 80%" class="twocol">';
    foreach( sort keys %{$X} ) {
      $html .= sprintf $ROW_T, encode_entities( $_ ), $self->value( $r->headers_out->{ $_ } );
    }
    $html .= '
  </dl>';
  }

  $X = $r->err_headers_out();
  if( keys %{$X} ) {
    $html .= '

  <h3 class="keep">err headers out</h3>
  <dl style="font-size: 80%" class="twocol">';
    foreach( sort keys %{$X} ) {
      $html .= sprintf $ROW_T, encode_entities( $_ ), $self->value( $r->err_headers_out->{ $_ } );
    }
    $html .= '
  </dl>';
  }

  #-- Dump the contents of the notes and pnotes array...
  $html .= q(
</div>

<div id="t_notes">
  <h3 class="keep">notes</h3>);
  $X = $r->notes();
  if( keys %{$X} ) {
    $html .= '
  <dl style="font-size: 80%" class="twocol">';
    foreach( sort keys %{$X} ) {
      $html .= sprintf $ROW_T, encode_entities( $_ ), $self->value( $X->{ $_ } );
    }
    $html .= '
  </dl>';
  } else {
    $html .= '
  <p>No notes set</p>';
  }
  $html .= '
  <h3 class="keep">pnotes</h3>';
  $X = $r->pnotes();
  if( keys %{$X} ) {
    $html .= '
  <dl style="font-size: 80%" class="twocol">';
    foreach( sort keys %{$X} ) {
      $html .= sprintf $ROW_T, encode_entities( $_ ), $self->value( $X->{ $_ } );
    }
    $html .= '
  </dl>';
  } else {
    $html .= '
  <p>No pnotes set</p>';
  }

  #-- Dump the perl include path (@INC)
  my $tx = $self->twocol({'class'=>'twothird leftalign'});
  foreach (sort keys %INC) {
    next unless m{[.]pm\Z}mxs;
    next if     m{/Startup(?:/.*)?[.]pm}mxs;
    (my $x = $_) =~ s{/}{::}mxsg;
    $x =~s{[.]pm\Z}{}mxs;
    $tx->add_entry( $x , $INC{$_} );
  }
  $html .= q(
</div>

<div id="t_inc">
  <h3 class="keep">Include path</h3>
  <ul>);
  foreach( @INC ) {
    $html .= sprintf $LIST_T, encode_entities( $_ );
  }

  #-- Dump the modules included at this point in time
  $html .= sprintf '
  </ul>
  %s
</div>

<div id="t_modules">
  <h3 class="keep">Modules</h3>
  <p>The following modules are already in Apache:</p>
  <ul>%s
  </ul>
</div>
',  $tx->render,
    $self->modules(q(::));

  my $user = $self->user;
  if( $user->logged_in ) {
    my $t = $self->twocol;
    $t->add_entry( 'Unique ID', $user->uid );
    $t->add_entry( 'Username',  $user->username );
    $t->add_entry( 'Name',      $user->name );
    $t->add_entry( 'Ldap ID',   $user->ldap_id || q(-) );
    $t->add_entry( 'Method',    $user->auth_method );
    $t->add_entry( 'Email',     $user->email   || q(-)  );
    $t->add_entry( 'State',     $user->status  || q(-)  );
    $t->add_entry( 'Groups',   sprintf '<ul>%s</ul>', join q(), map { "<li>$_</li>" } $user->groups ) if $user->groups;
    my $d = $user->data;
    $t->add_entry( 'Data', $self->pre_dumper( $d ) );
    $html .= sprintf  '
<div id="t_user">
  <h3 class="keep">User details</h3>
  %s
</div>', $t->render;
  } else {
    $html .= '<div id="t_user"><h3 class="keep">User details</h3><p>User not logged in</p></div>';
  }
  $html .= '
  </div>
  </div>';

  #-- Close the two containing divs...
  return $html;
}
##use critic

sub env_var {
#@param (self)
#@param (string) $name - name of environment variable.
#@return (string) "HTML safe" formatted value of variable or '-'
## Formats an environment variable's value for display

  my($self,$name)  = @_;
  my $value = $ENV{ $name };
  ## Split long "multi" values so that entries are displayed on separate lines
  $value =~ s{:}{:\n}mxgs   if $name eq 'PATH';
  $value =~ s{;\s}{;\n}mxgs if $name eq 'HTTP_COOKIE';
  $value =~ s{,}{,\n}mxgs   if $name eq 'HTTP_ACCEPT';
  $value =~ s{,\s}{,\n}mxgs if $name eq 'HTTP_X_FORWARDED_FOR';

  $value = encode_entities( $value );
  $value =~ s{\n}{<br />}mxgs;
  return $value || q(-);
}

sub hex_encode {
  my( $self, $value ) = @_;
  $value = encode_entities( $value );
  $value =~ s{\&\#(\d|[12]\d|3[01]);}{[$1]}mxgs;
  return $value;
}

sub value {
#@param (self)
#@param (hashref|arrayref|scalar) $x - variable
#@return (string) "HTML safe" formatted value of variable or '-'
## Formats a scalar, arrayref or hashref for display

  my($self,$x) = @_;
  return q(-) unless $x;
  my $return = ref($x) eq 'HASH'  ? sprintf '{ %s }', join ' , ', map { $self->hex_encode( $_.': '.$x->{$_} ) } sort keys %{$x}
             : ref($x) eq 'ARRAY' ? sprintf '[ %s ]', join ' , ', map { $self->hex_encode( $_ ) } @{$x}
             : ref($x)            ? sprintf '<pre>%s</pre>', $self->hex_encode( $self->raw_dumper( $x ) )
             : $x =~ m{\n}mxs      ? sprintf "\n      <pre>%s</pre>", $self->hex_encode($x )
             :                        $self->hex_encode( $x )
             ;
  return $return || q(-);
}

sub modules {
#@param (self)
#@param (string) $module name of module!
#@param (int) $depth - depth of parsing - don't go too deep - limit to a depth of 15! - incase anything weird has happened to the symbol table!
#@return (string) HTML nested bulletted list of modules
## Returns a list of modules currently loaded into the perl interpreter.
  my( $self, $module, $depth ) = @_;
  $depth ||= 0;
  return if $depth > $MAX_DEPTH;

  my $html = q();
  no strict 'refs'; ##no critic (NoStrict)
  foreach my $mod ( sort grep { m{::\Z}mxs } keys %{$module} ) {
    next if $mod eq 'main::'; # Everything is duplicated in main space so if you follow this you get everything multiple times.
    my $ver = q($).$module.$mod.'VERSION'; # Grab version if it exists (need to use string eval)
    my $ret= eval $ver; ##no critic (StringyEval)
    my $pad = q(    ) x $depth;
    $html .=  sprintf "\n%s    <li>%s (%s)",$pad,encode_entities($mod),encode_entities($ret||q(-));
    my $t = $self->modules("$module$mod",$depth+1);
    if( $t ) {
      $html .= "\n$pad      <ul>$t\n$pad      </ul>\n$pad    </li>";
    } else {
      $html .= '</li>';
    }
  }
  return $html;
}

1;

__END__

h3. Syntax

<% Developer_Information
%>

h3. Purpose

Dump various information about the mod_perl instance and Apache process:

* information about the URI;

* general information about the server and the request;

* the environment (before and after expansion)

* the current configuration about the virtual server

* the headers sent to/from the browser

* notes/pnotes attached to the Apache response

* the perl include path

* modules currently loaded

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes
