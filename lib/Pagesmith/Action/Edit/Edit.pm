package Pagesmith::Action::Edit::Edit;

## Handles error messages
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
use Carp qw(carp);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR $EVAL_ERROR $UID);
use HTML::HeadParser;
use Apache2::RequestUtil;
use File::Basename qw(dirname);

use Readonly qw(Readonly);
Readonly my $ACCESS_LEVEL   => 1;
Readonly my $MESSAGE_LENGTH => 12;

use Pagesmith::Utils::HTMLcritic;
use Pagesmith::Utils::SVN::Config;
use Pagesmith::ConfigHash qw(docroot get_config server_root);
use Pagesmith::Core qw(safe_md5 safe_base64_encode user_info);

## Package globals...

my %HEADER_MAP = qw(
  Title              title
  X-Meta-Author      author
  X-Pagesmith-QrCode qrcode
  X-Meta-Description description
  X-Meta-Keywords    keywords
);

my %PARTS_TO_CHECK = qw(
  nav     id
  rhs     id
  main    id
  panel   class
);

## Accessors......

sub contents {
  my $self = shift;
  return $self->{'_data'}{'contents'};
}

sub path {
  my $self = shift;
  return $self->{'_data'}{'path'};
}

sub url {
  my $self = shift;
  return $self->{'_data'}{'url'};
}

sub details {
  my( $self, @pars ) = @_;
  return $self->{'_data'}{'details'}{$pars[0]} if @pars;
  return $self->{'_data'}{'details'};
}

## Security function

## General functions to - read/write file, and to set request parameters
sub _set_filename {
  my $self = shift;
  $self->r->filename( $self->path );
  $self->r->uri( q(/).$self->url );
  return $self;
}

sub _get_contents {
  my $self = shift;
  if( open my $fh, '<', $self->path ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    $self->{'_data'}{'contents'} = <$fh>;
    close $fh; ## no critic (RequireChecked)
    $self->{'_data'}{'contents'} =~ s{^\xEF\xBB\xBF}{}mxs;
    return 1;
  }
  return;
}

sub _write_file {
  my( $self, $new_contents ) = @_;
  if( open my $fh, '>', $self->path ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $return_value = print {$fh} $new_contents;
    unless ( $return_value    ) {
      carp 'Unable to write new contents to file!';
    }
    $self->{'_data'}{'contents'} = $new_contents;
    close $fh; ## no critic (RequireChecked)
    return $return_value; ## 0 if failed to write!
  }
  return;
}

sub grab_head_data {
  my( $self, $html_page ) = @_;
  my $head_data   = {};
  if( $html_page =~ m{<head>(.*)</head>}mxs ) {
    ( my $head = $1 ) =~ s{<%[^>]+%>}{}mxsg; ## Remove any <% %> tags in head as these break header parser
    $head =~ s{(<%)(\s[^>]*\s%>)}{}smx;
    my $head_parser = HTML::HeadParser->new();
    my $head_info   = $head_parser->parse($head);
    if( $head_info ) {
      foreach my $key ( keys %HEADER_MAP ) {
        push @{$head_data->{ $HEADER_MAP{$key} }}, $head_info->header( $key );
      }
    } else {
      $head_data = map { ( $_ => [] ) } values %HEADER_MAP;
    }
  } else {
    $head_data = map { ( $_ => [] ) } values %HEADER_MAP;
  }
  return $head_data;
}

## Main run command
## no critic (Complexity)
sub run {
  my $self = shift;

  return unless $self->user->fetch;

  my $flags = $self->edit_flag;

  return $self->no_content unless $flags eq 'any' || $flags eq 'self'; ## Not editable!

  return $self->wrap( 'Unauthorised user', '<p>Your user does not have access to edit webpages</p>' )->ok
    unless $self->is_valid_user( $flags );

  my $docroot = docroot;
  $self->no_qr;  ## Just a few headers! don't create a QR graphic and don't include spelling on dev site!

  ## Grab information about the URL and the contents from the path.....
  my $url   = join q(/), grep { !m{\A[.]}mxs } $self->path_info; ## Remove '.' files!
  my $path  = realpath( join q(/), $docroot, $url );

  ## Check that the file exists.....
  return $self->no_content unless -e $path && ( -f $path || -d $path && -f ($path.='/index.html') ); ## no critic (Filetest_f)
     ## I do want to know that it is physical file!
  ## Check it is actually under docroot (call me paranoid!)

  $path =~ s{//+}{/}mxgs; ## Remove multiple q(/)s from path...
  return $self->no_content unless $docroot eq substr $path, 0, length $docroot;

  my $info_results  = $self->run_cmd( [$self->svn_cmd, qw(info --non-interactive),$path] );
  my $repos_details = $self->get_repos_details( $info_results, $path );

  return $self->wrap( 'Non publishable directory', '<p>This area can not be maintained by web-interface</p>' )->ok
    unless $repos_details; ## Can't do anything unless in repository root!

  ## Set repository and user!
  return $self->wrap( 'Non publishable directory', '<p>This area can not be maintained by web-interface</p>' )->ok
    unless $self->svn_config->set_repos( $repos_details->{'root'} );   ## Not a valid repository

  return $self->wrap( 'Unauthorised user', '<p>Your user does not have access to this repository</p>' )->ok
    unless $self->svn_config->set_user( $self->user->ldap_id );        ## Not a valid user for this repository

  return $self->wrap( 'Unauthorised user', '<p>You do not have permission to work on this path</p>' )->ok
    unless $self->svn_config->can_perform( $repos_details->{'path'}, 'update' );

  $self->{'_data'} = { 'url'  => $url, 'path' => $path, 'details' => $repos_details };

  ## Editing web pages....
  my $action = $self->param('act') || q();
  if( $action ) {
    $action = "svn_$action";
    if( $self->can($action) ) {
      my $results = $self->$action;
      if( ref $results ) { ## We have a problem
        my $success = 1;
        foreach( @{$results} ) {
          $success *= $_->{'success'};
        }
        return $path =~ m{[.]html\Z}mxs ? $self->redirect( "/$url" ) : $self->redirect( "/action/Edit/$url" ) if $success;
        $self->wrap( 'Unable to complete action', $self->pre_dumper( $results ) );
      } else {
        return $results;
      }
    }
  }

  return $self->run_html if $path =~ m{[.]html\Z}mxs; ## HTML page
  return $self->run_inc  if $path =~ m{[.]inc\Z}mxs;  ## Include file
  return $self->no_content;
}
## use critic

## handle includes... content!
sub run_inc {
  my $self = shift;
  return $self->no_content      unless $self->_get_contents;
  return $self->handle_post_inc if     $self->_set_filename->is_post;
  return $self->render_inc;
}

sub tidy_contents {
  my $self = shift;
  ( my $contents = $self->param('content') ) =~ s{\r}{}mxgs;
  $contents =~ s{\A\s*\n}{}mxs;
  $contents =~ s{\n\s*\Z}{}mxs;
  return $contents;
}
sub handle_post_inc {
  my $self = shift;


  return $self->wrap( 'Unable to update file',
    '<p>File has been updated by somebody else</p>')->ok
    unless $self->param('checksum') eq safe_md5( $self->contents );

  my $contents = $self->tidy_contents;
  return $self->redirect( '/action/Edit/'.$self->url ) if $self->_write_file( $contents );

  return $self->wrap( 'Unable to update file', '<pre>'.$self->encode($contents).'</pre>' )->ok;
}

sub render_inc {
  my $self          = shift;
  my $inc           = $self->contents;
  my $checksum      = $self->param( 'checksum' ) || q();
  my $inc_checksum  = safe_md5( $inc );
  my $is_inc_panel  = $inc =~ m{\A\s*<div[^<]+class\s*=\s*(["'])([-\w\s]+\s|)panel(|[-\w\s]+\s)\1}mxs; ## no critic (ComplexRegexes)
  my $file_inc = sprintf '<%% File /%s %%>', $self->encode( $self->url );
  ## no critic (ImplicitNewlines)
  my $html = sprintf '<div class="panel"><h3>Edit include: /%s</h3>
    <form action="" method="post">
      <div class="c">
      <input type="hidden" name="checksum" value="%s" />
      <textarea style="width:98%%; height:20em" name="content">%s</textarea>
      <p class="r"><input type="submit" value="update>>" /></p>
      </div>
    </form>
    %s
    </div>
    %s
  ',
    $self->encode( $self->url ),
    $inc_checksum,
    $self->encode( $inc ),
    $is_inc_panel ? q() : $file_inc,
    $is_inc_panel ? $file_inc : q()
    ;
  ## use critic
  return $self->wrap_no_heading( 'Edit include file', $html )->ok;
}

sub update_page {
  my $self = shift;
  my ($start,$body_attrs,$body,$end)
    = $self->contents =~ m{\A(.*)<body([^>]*)>(.*)</body>(.*)\Z}mxs;

  my $body_checksum = safe_md5( $body );
  return {(
    'message' => 'Unable to update page as there has been an underlying change to the webpage stored on disk',
  )} unless $body_checksum eq $self->param( 'checksum' );

  ## Grab the head block!!!
  my ($head_start,$head_content,$head_end);
  if( $start =~ m{\A(.*?<head>)(.*?)(</head>.*)\Z}mxs ) {
    ($head_start,$head_content,$head_end) = ($1,$2,$3);
    ## Remove the tags we are going to put back in !!!!
    $head_content =~ s{<title>(.*)</title>}{}mxs;
    $head_content =~ s{<meta([^>]+)http-equiv\s*=\s*(["'])(x-pagesmith-qrcode)\2([^>]*)>}{}mxsgi;    ## no critic (ComplexRegexes)
    $head_content =~ s{<meta([^>]+)name\s*=\s*(["'])(author|description|keywords)\2([^>]*)>}{}mxsgi; ## no critic (ComplexRegexes)
    $head_content =~ s{\n\s+\n}{\n}mxgs;
  } else {
    $head_start = qq($start<head>);
    $head_end   = q(</head>);
    $head_content = q();
  }
  ## Loop through head parts and if we have a match with attributes that form writes remove them!
  ## Now put back head...
  ## Push title back....
  $head_start .= sprintf qq(\n  <title>%s</title>), $self->encode( $self->param('title') );
    ## Remove any current qrcode stuff....
    ## Push new qrcode stuff onto $start....
  foreach my $value ( split m{\s+}mxs, $self->param( 'qrcode' ) ) {
    $head_start .= sprintf qq(\n  <meta http-equiv="%s" content="%s" />),
      'X-Pagesmith-QrCode', $self->encode( $value );
  }
  foreach my $attr ( qw(author description keywords) ) {
    my $val = $self->trim_param( $attr );
    next unless $val;
    $head_start .= sprintf qq(\n  <meta name="%s" content="%s" />),
      $attr, $self->encode( $val );
  }

  ## Fix body attribute....
  $body_attrs =~ s{\s*(id)\s*=\s*(["'])(.*?)\2\s*}{ }mxgs;
  my $val = $self->trim_param( '_id' );
  $body_attrs .= sprintf ' id="%s"', $self->encode( $val ) if $val;
  $body_attrs =~ s{\s+}{ }mxgs;

  ## Tidy up body input...
  $body = $self->tidy_contents;

  return {(
    'html' => sprintf qq(%s%s%s<body%s>\n%s\n</body>%s),
    $head_start, $head_content, $head_end, $body_attrs, $body, $end,
  )};
}

sub run_html {
  my $self = shift;
  return $self->no_content       unless $self->_get_contents;
  return $self->handle_post_html if     $self->_set_filename->is_post;
  return $self->render_html;
}

sub handle_post_html {
  my $self = shift;
  my $part = $self->param( 'part' ) || q();

  my $result;
  if( $part eq 'page' ) {
    $result = $self->update_page();
  } else { ## Now we are changing a div....
    ## Find the div
    ## Check the checksum
    $result = $self->update_part( $part );
  }
  my $message = q();
  if( exists $result->{'message'} ) {
    $message = $result->{'message'};
  } else {
    $message = $self->run_critic( $result->{'html'} );
    return $self->done unless $message; ## No message as was successful! Done is what self->redirect would have returned!
    $self->r->notes->set( 'html', $result->{'html'} ); ## Hopefully this should give error messages in the SVN panel!
  }
  return $self->render_html( $message );
}

sub grab_inner_html {
  my( $self, $body_ref ) = @_;
  my $sub_divs   = 0;
  my $inner_html = q();
  while( $sub_divs >= 0 ) {
    if( ${$body_ref} =~ s{\A(.*?)<(/?)div([^>]*)>}{}mxs ) {
      if( $2 eq q(/) ) {
        $inner_html .= $1;
        $sub_divs--;
        $inner_html .= '</div>' if $sub_divs >= 0;
      } else {
        $inner_html .= "$1<div$3>";
        $sub_divs++;
      }
    } else {
      return last; ## Jump out of loop!
    }
  }
  return $inner_html;
}

sub update_part {
  my( $self, $part ) = @_;
  return { 'message' => 'Do not know how to edit that part....' } unless exists $PARTS_TO_CHECK{ $part };

  my ($start,$body_attrs,$body,$end) = $self->contents =~ m{\A(.*)<body([^>]*)>(.*)</body>(.*)\Z}mxs;

  my $to_check = $PARTS_TO_CHECK{ $part };
## create new HTML...
  my $new_body = q();
  my $panels   = 0;
  while( $body =~ s{\A(.*?)<div([^>]*)>}{}mxs ) {
    $new_body .= $1;
    my $attrs = $2;
    my $match = 0;
    ## Get attributes....
    if( $to_check eq 'id' && $attrs =~ m{\bid\s*=\s*(["'])(\w+)\1}mxs ) {
      $match = 1 if $2 eq $part;
    } elsif( $to_check eq 'class' && $attrs =~ m{\bclass\s*=\s*"([^"]+)"}mxs || $attrs =~ m{\bclass\s*=\s*'([^']+)'}mxs ) {
      my %classes = map { ($_=>1) } split m{\s+}mxs, $1;
      if( exists $classes{ $part } ) {
        $panels ++;
        $match = 1;
      }
    }
    if( $match ) {
      ## Look for closing </div>
      my $inner_html = $self->grab_inner_html( \$body );

      if( $to_check eq 'id' || $panels == $self->param('panel') ) {
        return {( 'message' => 'Unable to update page as there has been an underlying change to the webpage stored on disk' )}
          unless safe_md5( $inner_html ) eq $self->param( 'checksum' );
          ## copy entry from 'content' here ... we will need to fix ids/classes of containing div
        $attrs = $self->update_attrs( $to_check, $attrs );
        $new_body .= sprintf qq(<div%s>\n%s\n</div>), $attrs, $self->tidy_contents;
      } else {
        ### We need to put the HTML from the file in here....
        $new_body .= sprintf '<div%s>%s</div>', $attrs, $inner_html;
      }
    } else {
      ### We just need to put the HTML from the file in here!
      $new_body .= sprintf '<div%s>', $attrs;
    }
  }
  return {( 'html' => sprintf qq(%s<body%s>\n%s%s</body>%s), $start, $body_attrs, $new_body, $body, $end )};
}

sub update_attrs {
  my( $self, $to_check, $attrs ) = @_;
  unless( $to_check eq 'id' ) {
    $attrs =~ s{\bid\s*=\s*(["'])[-\w]+\1}{}mxs;
    my $new_id = $self->trim_param('_id');
    $attrs .= sprintf ' id="%s"', $self->encode( $new_id ) if $new_id;
  }
  $attrs =~ s{\bclass\s*=\s*(["'])[-\s\w]+\1}{}mxs;
  my $new_class = $self->trim_param('_class');
  if( $to_check eq 'class' ) {
    $attrs .= $new_class ? sprintf ' class="panel %s"', $self->encode( $new_class )
            :              ' class="panel"'
            ;
  } else {
    $attrs .= $new_class ? sprintf ' class="%s"', $self->encode( $new_class ) : q();
  }
  $attrs =~ s{\s+}{ }mxgs;
  return $attrs;
}

sub run_critic {
  my( $self, $new_html  ) = @_;
  my $filename = $self->tmp_filename('html');
  my $flag = open my $fh, '>', $filename;
  if( $flag ) {
    ## Written temporary file!
    my $return_value = print {$fh} $new_html ;
    close $fh; ## no critic (RequireChecked)
    unless( $return_value ) {
      unlink $filename; ## Remove it as partly written!
      return 'Unable to execute tidy - cannot write temporary file' ;
    }
    ## Run HTML tidy on page!
    my $critic = Pagesmith::Utils::HTMLcritic->new( $filename, $ACCESS_LEVEL );
    my $critic_flag = $critic->check;
    $self->r->pnotes( 'critic', $critic );

    ## This page is OK! So we write back the contents and then loop back to edit page!
    return 'Unable to update file - critic errors!'
      if $critic_flag || $critic->n_errors || $critic->n_warnings || $critic->xml_error;
    if( $self->_write_file( $new_html ) ) {
      $self->redirect( '/action/Edit/'.$self->url );
      return;
    }
    return 'Unable to update file';
  }
  return 'Unable to execute tidy - cannot write temporary file';
}

sub render_html_page {
  my( $self, $part, $start, $body_attrs, $body ) = @_;

  my $body_checksum = safe_md5( $body );
  my $checksum      = $self->param( 'checksum' ) || q();

  return
    sprintf '<div class="panel"><h3><a href="?part=page;checksum=%s">Edit page</a></h3></div>',
      $body_checksum unless $part eq 'page' && $checksum eq $body_checksum;

  ## Grab body head content....
  my $input_content = defined $self->param( 'content' ) ? $self->param( 'content' ) : $body; ## Use the input version if set

  my $head_data = $self->grab_head_data( $start );
  my $form_stuff = q();
  foreach my $key ( sort keys %{$head_data} ) {
    my $value = defined $self->param( $key ) ? $self->trim_param( $key ) : join q( ), @{ $head_data->{$key} };
    $form_stuff .= sprintf '<dt><label for="form_%s">%s</label></dt><dd><input id="form_%s" name="%s" value="%s" /></dd>',
      $key, ucfirst $key,
      $key, $key,
      $self->encode( $value );
  }
  my $id      = $body_attrs =~ m{\bid\s*=\s*(["'])([-\w\s]*)\1}mxs    ? $2 : q();
  ## no critic (ImplicitNewlines)
  return sprintf '
  <div class="panel"><h3>Edit page: /%s</h3>
    <form action="" method="post">
      <h4>Title and Meta tags</h4>
      <dl>
      %s
      </dl>
      <h4>Body attributes</h4>
      <dl>
        <dt><label for="form__id">Body ID</label></dt>
        <dd><input id="form__id" name="_id" value="%s" /></dd>
        <dd>This is used to modify the CSS of the page</dd>
      </dl>
      <div class="c">
      <input type="hidden" name="part" value="page" />
      <input type="hidden" name="checksum" value="%s" />
      <textarea style="width:98%%; height:20em" rows="10" cols="80" name="content">%s</textarea>
      <p class="r"><input type="submit" value="update>>" /></p>
      </div>
    </form>
  </div>',
    $self->encode( $self->url ),
    $form_stuff,
    $self->encode( $id ),
    $body_checksum,
    $self->encode( $input_content );
  ## use critic
}

sub render_html_id {
  my( $self, $part, $id, $attrs, $t_body ) = @_;
  $attrs ||= q();
  my $sub_divs   = 0;
  my $inner_html  = q();
  while($sub_divs>=0) {
    if( $t_body =~ s{\A(.*?)<(/?)div([^>]*)>}{}mxs ) {
      if( $2 eq q(/) ) {
        $inner_html .= $1;
        $sub_divs--;
        $inner_html .= '</div>' if $sub_divs >= 0;
      } else {
        $inner_html .= "$1<div$3>";
        $sub_divs++;
      }
    } else {
      last;
    }
  }

  my $block_checksum = safe_md5( $inner_html );
  my $checksum      = $self->param( 'checksum' ) || q();

  return sprintf q(<div%s><div class="panel"><h3><a href="?part=%s;checksum=%s">Edit %s</a></h3></div>),
    $attrs, $id, $block_checksum, $id
    unless $part eq $id && $block_checksum eq $checksum;

  my $classes= $attrs =~ m{\bclass\s*=\s*(["'])([-\w\s]*)\1}mxs ? $2 : q();
  my $input_content = defined $self->param( 'content' ) ? $self->param( 'content' ) : $inner_html; ## Use the input version
  ## no critic (ImplicitNewlines)
  return sprintf q(
    <div%s>
      <div class="panel">
        <h3 class="editbox">Edit %s</h3>
        <form action="" method="post">
          <dl>
            <dt><label for="form__class">Classes</label></dt>
            <dd><input id="form__class" name="_class" value="%s" /></dd>
          </dl>
          <div class="c">
            <input type="hidden" name="part" value="%s" />
            <input type="hidden" name="checksum" value="%s" />
            <textarea style="width:98%%; height:20em" name="content">%s</textarea>
            <p class="r"><input type="submit" value="update>>" /></p>
          </div>
        </form>
      </div>),
    $attrs,
    $id,
    $self->encode( $classes ),
    $id,
    $block_checksum,
    $self->encode( $input_content )
    ;
}

sub render_html_class {
  my( $self, $classes, $attrs, $panel_number, $body_ref ) = @_;

  ## Look for closing </div>
  my $sub_divs   = 0;
  my $inner_html = q();
  while($sub_divs>=0) {
    if( ${$body_ref} =~ s{\A(.*?)<(/?)div([^>]*)>}{}mxs ) {
      if( $2 eq q(/) ) {
        $inner_html .= $1;
        $sub_divs--;
        $inner_html .= '</div>' if $sub_divs >= 0;
      } else {
        $inner_html .= "$1<div$3>";
        $sub_divs++;
      }
    } else {
      last;
    }
  }
  $attrs   ||= q();
  my $panel   = $self->param('panel')||q();
  $classes =~ s{(\A|\s)panel(\Z|\s)}{ }mxs;
  my $id = $attrs =~ m{\bid\s*=\s*(["'])([-\w\s]*)\1}mxs ? $2 : q();

  my $panel_checksum = safe_md5( $inner_html );
  my $checksum      = $self->param( 'checksum' ) || q();

  return sprintf q(<div%s><h3 class="editbox"><a href="?part=panel;panel=%d;checksum=%s">Edit panel</a></h3>%s</div>),
    $attrs, $panel_number, $panel_checksum, $inner_html
    unless $panel eq $panel_number && $panel_checksum eq $checksum;

  my $input_content = defined $self->param( 'content' ) ? $self->param( 'content' ) : $inner_html; ## Use the input version

  ## no critic (ImplicitNewlines)
  return sprintf q(
    <div%s>
      <h3 class="editbox">Edit panel</h3>
      <form action="" method="post">
        <dl>
          <dt><label for="form__id">ID</label></dt>
          <dd><input id="form__id" name="_id" value="%s" /></dd>
          <dt><label for="form__class">Classes</label></dt>
          <dd><input name="_class" id="form__class" value="%s" /></dd>
        </dl>
        <div style="padding-top: 5px;border-bottom: 1px solid #900; background-color: #fdb" class="c">
          <input type="hidden" name="part" value="panel" />
          <input type="hidden" name="panel" value="%d" />
          <input type="hidden" name="checksum" value="%s" />
          <textarea style="width:98%%; height:20em" name="content">%s</textarea>
          <p class="r"><input type="submit" value="update>>" /></p>
        </div>
      </form>
      %s
    </div>),
    $attrs,
    $self->encode( $id ),
    $self->encode( $classes ),
    $panel_number,
    $panel_checksum,
    $self->encode( $input_content ),
    $inner_html;
  ## use critic
}

sub render_html {
  my( $self, $message ) = @_;

  my ($start,$body_attrs,$body,$end) = $self->contents =~ m{\A(.*)<body([^>]*)>(.*)</body>(.*)\Z}mxs;

  my $part          = $self->param( 'part' )     || q();

  my $out_html = q();

  $out_html .= sprintf '<div class="panel box-warn"><h3>ERROR</h3><p>%s</p></div>', $message if $message;
  ## Make the body of the page editable....
  $out_html .= $self->render_html_page( $part, $start, $body_attrs, $body );

  my $panel_number = 0;

  ## Now we are going to have to loop through the divs to pick out (1) rhs/main/nav divs (2) "panel" divs
  while( $body =~ s{\A(.*?)<div([^>]*)>}{}mxs ) {
    $out_html .= $1; ## Copy stuff before the <div>
    my $attrs  = $2;
    ## Get attributes....
    if( $attrs =~ m{\bid\s*=\s*(["'])(rhs|main|nav)\1}mxs ) { ## Our meta navigation blocks: rhs, main & nav....
      my $id = $2;
      $out_html .= $self->render_html_id( $part, $id, $attrs, $body );
      next;
      ## We have an rhs/main/nav block to edit!
    }
    if( $attrs =~ m{\bclass\s*=\s*(["'])([-\w\s]*)\1}mxs ) { ## Now we are looking for panel contents...
      my $classes = $2;
      if( $classes =~ m{\b(panel)\b}mxs ) {
        $panel_number ++;
        $out_html .= $self->render_html_class( $classes, $attrs, $panel_number, \$body );
        next;
      }
    }
    $out_html .= qq(<div$attrs>);
  }
  $out_html .= $body;
  return $self->html->print( "$start<body$body_attrs>$out_html</body>$end" )->ok;
}

##
## Commands to allow a user to perform SVN actions...
##   revert
##   update
##   commit
##   add          (requries addfile - and possibly extending this - adddir)
##   stage        ( extension will require us to check that the repos has stage as well as publish branches
##   publish      ( to automate this could look for staging branch! )

sub svn_revert {
  my $self = shift;
  my $results = $self->run_cmd( [$self->svn_cmd,  qw(revert), $self->path ] );
  return [ $results ];
}

sub svn_update {
  my $self = shift;
  my $results = $self->run_cmd( [$self->svn_cmd, qw( update), $self->path ] );
  return [ $results ];
}

sub is_valid_message {
  my( $self, $message ) = @_;
  return 0 if length $message < $MESSAGE_LENGTH;
  return 0 unless $message =~ m{\s}mxs;
  return 1;
}

sub user_tweak {
  my $self = shift;
  return sprintf ' [by %s]', $self->user->ldap_id;
}

sub svn_add {
  my $self = shift;
  ## Does the user have add file permissions!
  my $message = $self->trim_param('message');
  return [ { 'success' => 0, 'error' => 'Commit message to short' } ] unless $self->is_valid_message( $message );

  my $tmp_filename = $self->tmp_filename;
  return $self->no_content unless $self->svn_config->can_perform( $self->details('path'), 'addfile' );
  if( open my $fh, q(>), $tmp_filename ) {
    print {$fh} $message.$self->user_tweak; ## no critic (RequireChecked)
    close $fh; ## no critic (RequireChecked)
    my $results_add = $self->run_cmd( [$self->svn_cmd, qw(add), $self->path ] );
    my $results_com = $self->run_cmd( [$self->svn_cmd, qw(commit -F), $tmp_filename, $self->path ] );
    unlink $tmp_filename;
    return [ $results_add, $results_com ];
  }
  return [ { 'success' => 0 , 'error' => 'Unable to create commit message' } ];
}

sub svn_commit {
  my $self = shift;
  my $message = $self->trim_param('message');
  return [ { 'success' => 0, 'error' => 'Commit message to short' } ] unless $self->is_valid_message( $message );
  my $tmp_filename = $self->tmp_filename;
  if( open my $fh, q(>), $tmp_filename ) {
    print {$fh} $message.$self->user_tweak; ## no critic (RequireChecked)
    close $fh; ## no critic (RequireChecked)
    my $results_com = $self->run_cmd( [ $self->svn_cmd, qw(commit -F), $tmp_filename, $self->path ] );
    unlink $tmp_filename;
    return [ $results_com ];
  }
  return [ { 'success' => 0 , 'error' => 'Unable to create commit message' } ];
}

sub svn_stage {
  my $self = shift;
  my $results = $self->run_cmd( [
    qw(/www/utilities/stage -v -v -v -b -m),
    safe_base64_encode($self->param('message').$self->user_tweak),
    $self->path ] );
 $self->dumper( $results );
  return [ $results ];
}

sub svn_publish {
  my $self = shift;
  my $results = $self->run_cmd( [
    qw(/www/utilities/publish -b -m),
    safe_base64_encode($self->param('message').$self->user_tweak),
    $self->path ] );
  return [ $results ];
}

1;
