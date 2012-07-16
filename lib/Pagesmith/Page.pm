package Pagesmith::Page;

## Base class to wrap pages...
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

use Readonly qw(Readonly);

Readonly my $ERROR_WIDTH         => 160;
Readonly my $STACKTRACE_MAXDEPTH => 10;
Readonly my $PERCENT             => 100;
Readonly my $DEFAULT_ZOOM        => 'n';

use base qw(Pagesmith::Support);

use APR::Table;
use Apache2::Request;
use URI::Escape qw(uri_escape_utf8);          ## URL encoding
use Cwd qw(cwd);                   ## Gets current working directory - used to default docroot to...
use Date::Format qw(time2str);     ## Formatting last modified dates
use English qw(-no_match_vars $PID $EVAL_ERROR $INPUT_RECORD_SEPARATOR);
use File::Basename qw(dirname);    ## Used to get server root from docroot! so we can get to templates directory
use File::Spec;                    ## Used to get server root from docroot! so we can get to templates directory
use HTML::Entities qw(encode_entities);     ## HTML entity escaping
use HTML::HeadParser;              ## Used to parse the HTML header
use List::MoreUtils qw(uniq);      ## To uniqify headers
use Time::HiRes qw(time);          ## Used to supply microsecond timing

use Pagesmith::Cache;              ## Wrapper around the memcached classes
use Pagesmith::ConfigHash qw(get_config can_cache docroot template_dir template_name server devel_realm is_developer can_name_space);
use Pagesmith::Core qw(fullescape safe_md5);  ## Extended version of md5 checksum which produces "file safe" strings
use Pagesmith::Message;            ## So we can store messages to squirt into developer templates or "link" in error log

sub tmp_filename {
## Return a temporary file name - that exists on real disk! - we may later delete
## this!
#@param $xtn/string The extension for the file if required.
#@return string A full path to a temporary file
  my ( $self, $xtn ) = @_;
  return get_config('RealTmp') . $PID . q(.) . time() . ( defined $xtn ? q(.) : q() ) . $xtn;
}

sub new {
## Constructor
#@param $r/Apache2::RequestRec Apache2 request object object
#@param hashref of parameters used to create the configuration
  my $class = shift;
  my $r     = shift;
  my $pars  = shift;

  my $self = {
    '_r'             => $r,
    '_type'          => exists $pars->{'type'} ? $pars->{'type'} : 'html',
    '_last_mod'      => exists $pars->{'last_mod'} ? $pars->{'last_mod'} : time2str( '%a, %d %b %Y %H:%M %Z', time ),
    '_filename'      => exists $pars->{'filename'}      ? $pars->{'filename'}      : q(),
    '_title'         => q(),
    '_uri'           => exists $pars->{'uri'}           ? $pars->{'uri'}           : q(),
    '_full_uri'      => exists $pars->{'full_uri'}      ? $pars->{'full_uri'}      : q(),
    '_template_flag' => exists $pars->{'template_flag'} ? $pars->{'template_flag'} : q(),
    '_template_type' => exists $pars->{'template_type'} ? $pars->{'template_type'} : q(),
    '_flags'         => exists $pars->{'flags'}         ? $pars->{'flags'}         : {},
    '_store'         => {},    ## To be used by components etc to pass messages and information between each other!
    '_messages'      => $r->pnotes( 'errors' ),
    '_developer'     => is_developer( $r->headers_in->get('ClientRealm') ),
  };
  bless $self, $class;

  return $self;
}

sub param {
  my( $self, @param ) = @_;
  return $self->apr->param( @param );
}

sub apr {
  my $self = shift;
  $self->{'_apr'} ||= Apache2::Request->new( $self->{'_r'} );
  return $self->{'_apr'};
}

## A series of lvalue accessors to get access to the
## appropriate elements of the object

sub developer {
  my $self = shift;
  return $self->{'_developer'};
}

sub template_flag {
  my $self = shift;
  return $self->{'_template_flag'};
}

sub template_type {
  my $self = shift;
  return $self->{'_template_type'};
}

sub r {
  my $self = shift;
  return $self->{'_r'};
}

sub type {
  my $self = shift;
  return $self->{'_type'};
}

sub last_mod {
  my $self = shift;
  return $self->{'_last_mod'};
}

sub title {
  my $self = shift;
  return $self->{'_title'};
}

sub filename {
  my $self = shift;
  return $self->{'_filename'};
}

sub full_uri {
  my $self = shift;
  return $self->{'_full_uri'};
}

sub uri {
  my $self = shift;
  return $self->{'_uri'};
}

sub flags {
  my $self = shift;
  return $self->{'_flags'};
}

sub can_ajax {
  my $self = shift;
  return unless exists $self->{'_flags'}{'a'};
  return $self->{'_flags'}{'a'} eq 'e';
}

sub zoom_level {
  my $self = shift;
  return $DEFAULT_ZOOM unless exists $self->{'_flags'}{'z'};
  return $self->{'_flags'}{'z'} =~ m{\A([snlxp])}mxs ? $1 : $DEFAULT_ZOOM;
}

sub content_type {

#@return The content type string for the current page.

## Returnsthe content type of the document based on the ct_flag and type
## flag ... basically only send xhtml if (ct_flag is xhtml OR default) AND
## the type is XHTML!
  my $self = shift;
  return $self->ct_flag =~ m{\A(xhtml|default)$}mxs && $self->type eq 'xhtml'
    ? 'application/xhtml+xml; charset=utf-8'
    : 'text/html; charset=utf-8';
}

sub push_message {
  my ( $self, @msgs ) = @_;
  push @{ $self->{'_messages'} }, Pagesmith::Message->new(@msgs);
  return;
}

## no critic (ExcessComplexity);
sub merge_cssjs {
#@ $type/string either "css" or "js" the type of object to merge, minify or expand
#@ $flag/string method either "merge", "minify" or "off"

## Merge CSS / JS files together (or split lines if off) and if requested minify
## (i.e. remove all unnecessary white space

  my ( $self, $type, $flag, @files ) = @_;
  ( my $dir = docroot() ) =~ s{/+\Z}{}mxs;
  my @html;
  ## Part 1 - not a merge - more a split - modify the html to include
  ## separate javascript and css files in each block!
  my $devel = $self->developer;
  my @files_to_include =
    grep { ref $_ || !m{\A\#}mxs }
    grep { $_ && ( $devel || !m{\bdeveloper\b}mxs ) || ref $_ }
    map  { ref $_ ? $_ : split m{\s+}mxs }
    @files;
  ## Rewrite this to cope with inline javascript passed as references...
  if ( $flag eq 'off' ) {
    if( $type eq 'css' ) {
      return join qq(\n), map {
        ref $_ ? qq(<style type="text/css">/*<![CDATA[*/\n${$_}/*]]>*/</style>\n)
               : sprintf q(<link rel="stylesheet" type="text/css" href="%s" />), encode_entities( $_ )
      } @files_to_include;
    }
    return join qq(\n), map {
      ref $_ ? qq(<script type="text/javascript">//<![CDATA[\n${$_}//]]></script>\n)
             : sprintf q(<script type="text/javascript" src="%s"></script>), encode_entities( $_ )
    } @files_to_include;
  }
  ## Part 2 - in this case we will do the merging!
  foreach ( @files_to_include ) {
    if( ref $_ ) {
      ##no critic (ImplicitNewlines)
      push @html, [
        '
/***********************************************************************
** INLINE CODE                                                        **
***********************************************************************/

',
        ${$_},
        undef,
      ];
      ## use critic
      next;
    }
    my $fn = qq($dir$_);
    if ( -e $fn && -f $fn ) { ## no critic (Filetest_f) - has to be a physical file!
      local $INPUT_RECORD_SEPARATOR = undef;    ## Stop mod_perl seg faulting!
      my $fh;
      if ( open $fh, '<', $fn ) {
        my $x = <$fh>;
        close $fh; ##no critic (CheckedSyscalls CheckedClose)
        ## Add a header in the HTML to be minified and merged!
        ##no critic (ImplicitNewlines)
        push @html, [
          sprintf( '
/***********************************************************************
** FILE: %-60s **
***********************************************************************/

', $_ ),
          $x,
          $fn,
        ];
        ##use critic (ImplicitNewlines)
      } else {
        $self->push_message( "Unable to open $type file $_", 'fatal' );
      }
    } else {
      $self->push_message( "Unable to find $type file $_", 'fatal' );
    }
  }
  my $uri  = safe_md5( join qq(\n), map { $_->[1] } @html );
  my $ch   = Pagesmith::Cache->new( 'tmpfile', qq(cssjs|$uri.u.$type) );
  my $ch_c = Pagesmith::Cache->new( 'tmpfile', qq(cssjs|$uri.c.$type) );
  my $stored_type = 'u';
  $ch->set( join "\n", map { ( $_->[0], $_->[1] ) } @html ) unless $ch->exists;

  if( $ch_c->exists ) {
    $stored_type = 'c';
  } else {
    my $fn = '/tmp/' . time() . q(.) . $PID . q(.) . $type;
    my $fh;
    if ( open $fh, '>', $fn ) {
      my $t = join q(),map { $_->[1] } @html;
      print {$fh} $t; ##no critic (CheckedSyscalls)
      close $fh; ##no critic (CheckedSyscalls CheckedClose)

      if( $type eq 'js' ) {
        system 'java', '-jar', '/www/utilities/jars/compiler.jar',
          '--js',                 $fn,
          '--js_output_file',     "$fn.out",
          '--compilation_level',  $flag eq 'advanced' ? 'ADVANCED_OPTIMIZATIONS' : 'SIMPLE_OPTIMIZATIONS';
        if ( open $fh, '<', "$fn.out" ) {
          local $INPUT_RECORD_SEPARATOR = undef;
          $t = <$fh>;
          close $fh; ##no critic (CheckedSyscalls CheckedClose)
          unlink "$fn.out" ;
        }
        if( length $t ) {
          $ch_c->set($t);
          $stored_type = 'c';
        }
      } else {
        system 'java', '-jar', '/www/utilities/jars/yuicompressor.jar',
          '-o', "$fn.out", $fn;
        if ( open $fh, '<', "$fn.out" ) {
          local $INPUT_RECORD_SEPARATOR = undef;
          $t = <$fh>;
          close $fh; ##no critic (CheckedSyscalls CheckedClose)
          unlink "$fn.out";
        }
        if( length $t ) {
          $ch_c->set($t);
          $stored_type = 'c';
        }
      }
      unlink $fn;
    } else {
      $ch->set( join q(), map { $_->[1] } @html );    ## Didn't compress
    }
  }
  my $URL = get_config('TmpUrl') . q(cssjs/) . $uri . q(.) . ( $flag eq 'minified' || $flag eq 'advanced' ? $stored_type : 'u' ) . q(.) . $type;
  return sprintf
    $type eq 'js' ?'<script type="text/javascript" src="%s"></script>' :  '<link rel="stylesheet" type="text/css" href="%s" />',
    $URL;
}
## use critic

sub minify_html {
  my( $self, $html_ref ) = @_;
  my $result = $self->run_cmd( [qw(java -jar /www/utilities/jars/htmlcompressor.jar --preserve-server-script --compress-js --js-compressor closure --compress-css --remove-intertag-spaces --remove-form-attr --remove-input-attr )], $html_ref );
  return unless $result->{'success'};
  ${$html_ref} = join qq(\n), @{$result->{'stdout'}};
  return 1;
}

sub compile_template {
## Compiles template - reads from the appropriate templates directory
## munges any stylesheet or script line containing multiple CSS or
## Javascript files respectively - using merge_cssjs
## returns the html of the template with the respective type either
## merged or minified!
  my $self = shift;

## Initialize with basic template!!
  ##no critic (ImplicitNewlines)
  my $html = '<html>
<head>
  <title><%= h:title %></title>
  <%= h:head %>
</head>
<body>
  <%content%>
<div id="#wrapper">
  <%~ Developer::Messages -stack_trace=-1 -all ~%>
</div>
</body>
</html>';
  ##use critic (ImplicitNewlines)
  my $js_flag  = get_config('JsFlag');
  my $css_flag = get_config('CssFlag');

  ## Stage 1 - get the template file! - if it exists use it!
  my @templates      = ( $self->template_type );
  my $found_template = 0;
  push @templates, 'normal' unless $self->template_type eq 'normal';
  foreach my $T (@templates) {
    my $fn = sprintf '%s/%s/%s.tmpl', template_dir(), $T, template_name();
    if ( -e $fn && -r $fn ) {
      local $INPUT_RECORD_SEPARATOR = undef;    ## LOCAL to stop mod_perl seg faulting!
      my $fh;
      if ( open $fh, '<', $fn ) {
        $html = <$fh>;
        close $fh; ##no critic (CheckedSyscalls CheckedClose)
      }
      $found_template = 1;
      last;
    }
  }
  $self->push_message( 'No template '.template_name().' found for domain ' . server(), 'error' ) unless $found_template;
## Stage 2 - look for javascript and css files in header/body
##         - load and merge them... and if required minify them

  $html =~ s{<link\s+rel="stylesheet"\s+type="text/css"\s+href="([^"]+)"\s*/>}{$self->merge_cssjs('css',$css_flag,$1)}egmxs;
  $html =~ s{<script\s+type="text/javascript"\s+src="([^"]+)"\s*>\s*</script>}{$self->merge_cssjs('js', $js_flag, $1)}egmxs;
## Stage 3 - optimize template...
  $html =~ s{<%~?\s+(\S*::)?Developer::[^>]\s+~?%>}{}mxgs unless $self->developer;

  return $html;
}

sub get_template {
## Grab the template for the site... first check to see if we can grab the
## template from memcached - if the site allows it..
## If not use compile_template to "compile" the template appropriately
  my $self = shift;
  my $val;
  my $ch;

  my $cachekey = $self->template_type.q(-). ($self->developer ? 'dev' : 'nondev');

  if( can_cache('templates') ) {
    $ch = Pagesmith::Cache->new( 'template', $cachekey );
    $val = $ch->get unless $self->flush_cache( 'template' );
  }

  unless ($val) {
    $val  =  $self->compile_template();
    $val  =~ s{\A.*<html>}{}mxs; ## Remove the <html> tag from the template!
    $val  =~ s{\A[ \t]+}{}mxgs;
    $val  =~ s{[ \t]+\Z}{}mxgs;
    if( defined $ch ) {
      $ch->set($val);
    }
  }
  ## Return the appropriate entry from the hash!
  return $val;
}

sub serve_html {
## Return true if the server is to return html source code...
## if either the ct_flag is set to html or the client can not accept xhtml.
  my $self = shift;
  my $t    = get_config('ContentType');
  return $t eq 'html' || $t eq 'xhtml_html' && $self->type eq 'html';
}

sub error {
## Just wrap string in an "error" class so that it can be styled
  my ( $self, $str ) = @_;
  return '<span class="web-error">' . $str . '</span>';
}

sub execute {
## Execute a directive ($action) with given parameter string, this is
## split up like a command line before being passed to the execute function
## in the approriate Component module 'Pagesmith::Component::'.$action...
## The output is cached if the component model raises a cache_key
## If the directive's "ajax" function returns true then a place holder is
## placed in the page which uses "/component" to call the "execute"
## function itself.
  my ( $self, $action, $parameters ) = @_;

  # Remove need to "::" in URLs... by splitting on "_" to separate the action out!
  # Note cannot have a component with an underscore in the name!
  $action = $self->safe_module_name( $action );

  if( $action =~ m{\A([a-z]+)::}mxis && ! can_name_space( $1 ) ) {
    warn "ACTION: cannot perform $action - not in valid name space\n";
    return q();
  }

  # Hide "Developer" components if not in a developer Realm
  return q() if $action =~ m{\bDeveloper::}mxs && ! $self->developer;

  my $module = 'Pagesmith::Component::' . $action;

  unless ( $self->dynamic_use($module) ) {
    ## Warn error message to error log, and output "error" block to
    ## the website.
    ( my $module_tweaked = $module ) =~ s{::}{/}mxgs;
    if( $self->dynamic_use_failure($module) =~ m{\ACan't\slocate\s$module_tweaked\.pm\sin\s\@INC}mxs ) {
      $self->push_message( "Unknown Component $action", 'fatal' );
      return $self->error( 'Component '. encode_entities( $action ).' not found' );
    }
    $self->push_message( "$action failed to compile: module $module:\n" . $self->dynamic_use_failure($module), 'fatal' );
    return $self->error( 'Component ' . encode_entities($action) . ' failed to compile' );
  }
  ## Create new component object...
  my $component;
  my $status = eval { $component = $module->new($self); };
  if( $EVAL_ERROR ) {
    $self->push_message( "$action failed to instantiate: module $module:\n" . $EVAL_ERROR, 'fatal' );
    return $self->error( 'Component ' . encode_entities($action) . ' failed to instantiate' );
  }
  ## If $component is type "ajax" return the ajax place holder!
  $component->parse_parameters($parameters);
  if ( $component->ajax && $self->can_ajax ) {
    my $caption = $component->ajax_message;
    return sprintf '<div class="ajax%s%s" title="/component/%s?pars=%s">%s</div>',
      $component->ajax =~ m{no-cache}mxs ? ' nocache' : q(),
      $component->ajax =~ m{click}mxs    ? ' onclick' : q(),
      encode_entities($action), uri_escape_utf8($parameters),
      $component->ajax_message;
  }
  ## finally we need to execute the component... first we
  my $cache_key = $component->cache_key;
  ## We are not going to cache this so just return it!
  unless ($cache_key) {
    my $t = eval { $component->execute; };
    if ($EVAL_ERROR) {
      $self->push_message( "$action failed to execute: module $module:\n$EVAL_ERROR", 'error' );
      return $self->error( 'Component ' . encode_entities($action) . ' failed to execute' );
    } else {
      return $t;
    }
  }
  ## Look up value in cache
  my $ch = Pagesmith::Cache->new( 'component', "$action|$cache_key" );
  my $c = $ch->get;
  ## generate and store the value in the cache...
  unless ($c) {
    $c = eval { $component->execute; };
    if ($EVAL_ERROR) {
      $self->push_message( "$action failed to execute (cache): module $module:\n$EVAL_ERROR", 'error' );
      return $self->error( 'Component ' . encode_entities($action) . ' failed to execute' );
    }
    $ch->set( $c, $component->cache_expiry );
  }
  return $c;
}

##no critic (ExcessComplexity)
sub _parse_head {
## Parse the head block to retrieve certain attributes... and map them through
## into a new header...
  my ( $self, $head ) = @_;
  my $pars = {};
  ## Parse the header block!
  my $head_parser = HTML::HeadParser->new();
  my $extra_head  = q();

  ## For each stylesheet "link" entry copy it through with the correct format
  ## ! or if there are is a <style>/*<![CDATA[(*/..../*)]]>*/</style> block
  ## OR <script language="text/javascript" src=""></script> or
  ## OR <script language="text/javascript"><![CDATA[(/*....*/)]]></script> or

  ## First we look through any css files that have been pushed in the page through the Action
  ## non-Ajax components etc... these are stored in the css_files flag!

  ## Now we include all manually added ones - note these will not get minified as the ones
  ## pushed from the action of from CssFile OR from any other components...
  ## Additionally we push through any Components that are in the head...

  while(
    $head =~ s{(<link)([^>]+>)}{}smx ||
    $head =~ s{(<style)([^>]+)>\s*(/\*\s*<!\[CDATA\[\s*\*/.*?/\*\s*\]\]>\s*\*/)\s*</style>}{}smx ||
    $head =~ s{(<script)([^>]+)>\s*(//\s*<!\[CDATA\[.*?//\s*\]\]>)?\s*</script>}{}smx ||
    $head =~ s{(<%)(\s[^>]*\s%>)}{}smx
  ) {
    my( $type, $tag, $txt ) = ($1,$2,$3);
    ## no critic (CascadingIfElse)
    if( $type eq '<link' ) {
      if ( $tag =~ m{rel\s*=\s*(['"])stylesheet\1}mxs
        || $tag =~ m{type\s*=\s*(['"])text/css\1}mxs ) {
        if ( $tag =~ m{href\s*=\s*(['"])(.*?)\1}mxs ) {
          $extra_head .= sprintf qq(  <link rel="stylesheet" type="text/css" href="%s" />\n), $2;
        }
      }
    } elsif( $type eq '<style' ) {
      $extra_head .= sprintf qq(  <style type="text/css">\n%s\n  </style>\n), $txt;
    } elsif( $type eq '<%' ) {
      $extra_head .= "$type$tag";
    } elsif( $type eq '<script' ) {
      if ( $tag =~ m{src\s*=\s*(['"])(.*?)\1}mxs ) {
        $extra_head .= sprintf qq(  <script type="text/javascript" src="%s"></script>\n), $2;
      } else {
        $extra_head .= sprintf qq(  <script type="text/javascript">\n%s  </script>\n), $txt if defined $txt;
      }
    }
    ## use critic
  }

  my $head_info   = $head_parser->parse($head);
  if ($head_info) {
    ## If valid.. grab the entries, title, meta:author,
    ## http-equiv:x-pagesmith-decor and copy them into the pars hash....
    my %map = qw(
      Title            title
      X-Meta-Author    author
      X-Pagesmith-Decor   template_flag
      X-Pagesmith-Expiry  expiry_time
      X-Last-Modified  last_modified
    );
    foreach ( keys %map ) {
      $pars->{ $map{$_} } ||= $head_info->header($_);
    }
    ## Copy through the meta/name headers, and pass throughthe http-equiv
    ## headers to the output - either by creating entries in the output header
    ## if called within apache OR by adding new http-equiv headers.
    foreach my $header_name ( uniq sort $head_info->header->header_field_names ) {
      next if $header_name eq 'Content-Base';    ## Skip
      next if $header_name eq 'IsIndex';         ## Skip
      next if $header_name eq 'Link';            ## Skip
      next if $map{$header_name};                ## Skip the ones that we are grabbing!
      if( $header_name =~ m{\AX-Meta-(.*)\Z}mxs) {
        if( $header_name =~ m{\AX-Meta-Charset-(.*)\Z}mxs) {
          next;
        } else {
          foreach my $v ( $head_info->header( $header_name ) ) {
            $extra_head .= sprintf qq(  <meta name="%s" content="%s" />\n),
              encode_entities( lc $1 ),
              encode_entities( $v );
          }
        }
      } else {
        foreach my $v ( $head_info->header($header_name) ) {
          if( $self->r ) {
            $self->r->headers_out->add( $header_name, $v );
          } else {
            $extra_head .= sprintf qq(  <meta http-equiv="%s" content="%s" />\n), encode_entities( lc $header_name ), encode_entities( $v );
          }
        }
      }
    }
  }
  $extra_head .=  sprintf qq(  <meta name="X-site-domain" content="%s" />\n), encode_entities( $self->r->server->server_hostname ) if $self->r->server->server_hostname ne $self->r->get_server_name;
  return ( $pars, $extra_head );
}
##use critic (ExcessComplexity)

sub _parse_body {
## Parse the body tag and the end of the html to see if there is (a) any
## extra javascript outside any html within the page - but within the body
## tags and (b) whether there is an id in the body tag...
  my ( $self, $body_tag, $html ) = @_;
  my $extra_body = q();

  ## Look for trailing <script></script> tags and take them out of the content -
  ## so they don't get wrapped in the page divs!
  while (
     $html =~ s{(<script[^>]+)>\s*(//\s*<!\[CDATA\[.*?//\s*\]\]>)?\s*</script>\s*\Z}{}mxs
  ) {
    my ( $tag, $txt ) = ( $1, $2 );
    $extra_body =
      $tag =~ m{src\s*=\s*(['"])(.*?)\1}mxs
      ? sprintf qq(  <script type="text/javascript" src="%s"></script>\n%s), $2, $extra_body
      : sprintf qq(  <script type="text/javascript">\n    %s  </script>\n%s), $txt, $extra_body;
  }

  my $req_div = get_config('RequiredDiv');
  if( defined $req_div )  {
    $html = qq(\n  <div class="$req_div">$html\n  </div>) unless $html =~ m{class="[^"]*\b$req_div\b[^"]*"}mxs;
  }
  ## Look for an id="" in the body tag - this is to allow the id to be passed
  ## through for formatting...
  my $body_attr = q();
  if( $body_tag =~ m{id="([-\w]+)"}mxs ) {
    $body_attr .= sprintf q( id="%s"), $1;
  } elsif( $self->r->pnotes('body_id') && $self->r->pnotes('body_id') =~ m{\A[-\w]+\Z}mxs ) {
    $body_attr .= sprintf q( id="%s"), $self->r->pnotes('body_id');
  }

  ## Return data structure... and cleaned HTML.
  my $ret = {
    'body_attr'  => $body_attr,
    'extra_body' => $extra_body,
    'html'       => $html,
  };
  return $ret;
}

sub decorate {
## This function decorates the contents of the HTML passed to the function
## with the appropriate template and expands any <% %> directives within the
## page.
  my ( $self, $html ) = @_;
  my $output;
  my $pars = {};
  ## Part 1 ... grab the head and information contained within it...
  ## Includes grabbing title, meta tags etc... Look for javascript/css in
  ## the head of the page and returns it ready for loading into the
  ## template.

  my $temp_flag = $self->template_flag || q();
  if ( $temp_flag eq 'runtime' ) {
    $output = $html;
  } else {
    my $extra_head = q();
    ( $pars, $extra_head ) =
        $html =~ m{<head>(.*)</head>}mxs
      ? $self->_parse_head($1)
      : ( {}, q() )    ## No head block!
      ;

    ## Minimal template wrapping - i.e. we don't run it through the body
    ## search... NOTE we have to run it through the head parsing to see
    ## if the meta-equiv "X_Pagesmith_Decor" head line is set to minimal
    ## (i.e. already parsed!)
    $pars->{'template_flag'} ||= $temp_flag ;
    if ( $pars->{'template_flag'} eq 'no' ) {
      return ( $html, $pars );
    }
    if ( $pars->{'template_flag'} eq 'runtime' ) {
      $output = $html;
    } else {
      if ( $pars->{'template_flag'} eq 'minimal' ) {
        ## We aren't going to do anything with the page template - but the
        ## page will do all the <% %> expansions!
        $output = $html;
      } else {
        ## Parse the HTML in the body to pull out anything additional in the body tag,
        ## and then parse the contents of the body to grab any trailing javascript!
        my $t = $html =~ m{<body([^>]*)>(.*)</body>}mxs
          ? $self->_parse_body( $1,  $2 )       ## We have body tags
          : $self->_parse_body( q(), $html )    ## We don't assume it is just raw HTML no head block either
          ;

        ## Grab the template (either from memcached or from disc, compile the CSS/JS
        ## changes and return the resultant template with placeholders:
        $output = $self->get_template();
        $output =~ s{<%\s*content\s*%>}{$t->{'html'}}mxs;    ## Include the content...

        $output =~ s{</head>}{<!-- EXTRA HEAD -->$extra_head</head>}mxs;
        $output =~ s{</body>}{<!-- EXTRA BODY -->$t->{'extra_body'}</body>}mxs;
        $output =~ s{<body(.*?)>}{<body$t->{'body_attr'}$1>}mxs;
      }
      ## We now need to to do all the <% %> expansions for directives and
      ## variables... this is moved out to a separate call so we can use it
      ## twice - once for the "compiled" template - and once for the "runtime"
      ## expanded pages which will see the additional <%~ ~%> directives
      ## processed - solves problems of stuff we don't necessarily want to
      ## cache!

      $self->_parse( \$output, $pars );
## Now we process the extra JS && CSS
      my $extra_js  = $self->_get_perl_js;
      my $extra_css = $self->_get_perl_css;
      $output =~ s{<!--\sEXTRA\sHEAD\s-->}{$extra_css}mxs;
      $output =~ s{<!--\sEXTRA\sBODY\s-->}{$extra_js}mxs;
    }
  }

  return ( $self->clean($output), $pars );
}

sub _get_perl_js {
  my $self = shift;
  my $js_files = $self->r->pnotes('js_files');
  return q() unless defined $js_files && @{$js_files};

  my $compress = get_config('JsFlag');
  my $markup   = q();

  if( $compress eq 'off' ) {
    return $self->merge_cssjs( 'js', 'off', @{$js_files} );
  } else {
    my $var_cache = Pagesmith::Cache->new( 'variable', sprintf 'cssjs|%s', safe_md5(join q( ), map { ref $_ ? ${$_} : $_ } @{$js_files} ) );
    $markup = $var_cache->get() unless $self->flush_cache( 'cssjs' );
    unless( $markup ) {
      $markup = $self->merge_cssjs( 'js', $compress, @{$js_files} );
      $var_cache->set( $markup );
    }
  }
  if( $self->r->pnotes('embed_js') && $markup =~ m{cssjs/(.*)\Z}mxs ) {
    my $js_cache = Pagesmith::Cache->new( 'tmpfile', qq(cssjs|$1) );
    my $js_string = $js_cache->get;
    return sprintf qq(<script type="text/javascript">//<![CDATA[\n%s//]]></script>), $js_string if $js_string;
  }
  return sprintf $markup;
}

sub _get_perl_css {
  my $self      = shift;
  my $css_files = $self->r->pnotes->{'css_files'}||{};
  return q() unless defined $css_files && keys %{$css_files};
  my $extra_css = q();
  my $compress = get_config('CssFlag');

  foreach my $css_flag ( 'all','if lt IE 9','if lt IE 8' ) { ## Need to get in right order!
    my $css_string;
    my @files    = @{$css_files->{$css_flag}||[]};
    next unless @files; ## No CSS of this class so skip to next class!
    if( $compress eq 'off' ) {
      $css_string = $self->merge_cssjs( 'css', 'off', @files ); ## We don't cache in this case!
    } else {
      my $var_cache = Pagesmith::Cache->new( 'variable',
        sprintf 'cssjs|%s', safe_md5(join q( ), map { ref $_ ? ${$_} : $_ } @files ) );
      $css_string = $var_cache->get() unless $self->flush_cache( 'cssjs' );
      unless( $css_string ) {
        $css_string = $self->merge_cssjs( 'css', $compress, @files );
        $var_cache->set( $css_string );
      }
      if( $self->r->pnotes('embed_css') && $css_string =~ m{cssjs/([^"]+)\Z}mxs ) {
        my $css_cache  = Pagesmith::Cache->new( 'tmpfile', qq(cssjs|$1) );
        my $tmp_string = $css_cache->get;
        $css_string = sprintf qq(<style type="text/css">/*<![CDATA[*/\n%s/*]]>*/</style>\n), $tmp_string if $tmp_string;
      }
    }
    $extra_css .= $css_flag eq 'all' ? $css_string
                : sprintf qq(<!--[%s]>\n  %s<![endif]-->), $css_flag , $css_string;
  }
  return $extra_css;
}

sub runtime_decorate {
## This function re-applies the templating post caching to include
## contents which are specific to the current "browser" session, e.g.
## through location (e.g. hinx/not hinx etc - see Realm) OR through
## additional user information! these are the same as the <% %> tags
## but have the addition of a ~ so are <%~ .... ~%> - currently an
## example of use is in the demo-2 template including the additional
## intweb etc links at the footer of the page!
  my ( $self, $html, $pars ) = @_;
  $html =~ s{<%~}{<%}mxgs;
  $html =~ s{~%>}{%>}mxgs;
  $self->_parse( \$html, $pars );
  return $html;
}

sub _parse {
## This is the function which expands the <% %> and <%~ ~%> templates
## out - takes as parameters a reference to the HTML along with a
## reference to a hash of parameters to expand using the <%= %> notation
  my ( $self, $out_ref, $pars ) = @_;

  ## Execute any directives in the page....
  ${$out_ref} =~ s{<%\s+([A-Z][\w:]+)\s+(%>|(.*?)\s+%>)}{$self->execute( $1, $3 )||q()}mxesg;

  ## Hide any content marked as <% hide %>..<% end %>
  ## <% If %> directive either returns <% hide %> or <% show %>
  ${$out_ref} =~ s{<%\s+hide\s+%>.*?<%\s+end\s+%>}{}mxsg;
  ${$out_ref} =~ s{<%\s+show\s+%>(.*?)<%\s+end\s+%>}{$1}mxsg;

  $pars->{'last_modified'} ||= $self->last_mod;
  $pars->{'uri'}           ||= $self->uri;
  $pars->{'base_url'}      ||= $self->base_url;
  $pars->{'full_uri'}      ||= $self->full_uri;

  ## entries are either...
  ## <%= {key} %>   - raw...
  ## <%= u:{key} %> - URL encoded
  ## <%= h:{key} %> - HTML encoded
  ## <%= m:{key} %> - URL encode ALL characters - even those readable ascii ones!
  ##                  this is used to hide email addresses for instance!
  ## keys are title, author, last_modified, uri, full_uri

  ${$out_ref} =~ s{<%=\s*?(\w+)\s*%>}{$pars->{$1}||q()}mxegs;
  ${$out_ref} =~ s{<%=\s*?u:(\w+)\s*%>}{uri_escape_utf8( $pars->{$1}||q() )}mxegs;
  ${$out_ref} =~ s{<%=\s*?h:(\w+)\s*%>}{encode_entities( $pars->{$1}||q() )}mxegs;
  ${$out_ref} =~ s{<%=\s*?m:(\w+)\s*%>}{fullescape( $pars->{$1}||q() )}mxegs;
  return $out_ref;
}

sub clean {
## XHTML clean up script - currently removes &nbsp; and converts to &#160; as
## &nbsp; is not a valid XML entity... and so not allowed in XHTML.
  my ( $self, $html ) = @_;
  $html =~ s{&nbsp;}{\&\#160;}mxgs;
  return $html;
}

sub xhtml2html {
## Converts XHTML to HTML - removes some un-required tags, and self
## closing tags which shouldn't be closed in HTML!!
  my ( $self, $xhtml ) = @_;
  ( my $html = $xhtml ) =~ s{</param>}{}mxgs;
  $html =~ s{<(img|br|input)([^>]+)\s*\/>}{<$1$2>}mxgs;
  $html =~ s{&\#160;}{\&nbsp;}mxgs;
  my ( $a, $head, $b ) = $html =~ m{^(.*<head>)(.*)(</head>.*)$}mxs;
  return $html unless defined $head;
  $head =~ s{"\s*/>}{">}mxgs;

  return "$a$head$b";
}

sub user {
  my $self = shift;
  return $self->SUPER::user( $self->r );
}

1;
