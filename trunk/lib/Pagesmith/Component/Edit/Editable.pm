package Pagesmith::Component::Edit::Editable;

## Include the source of the page - including spelling checking
## Looks for an HTTP out header X-Pagesmith-NoSpell
##  * If exists and is 1 - then the source of the page is marked-up
##  * If exists and is >1 - then the source of the page is not-marked-up and the block is missed entirely
##  * If doesn't exist OR is 0 - then the source is marked up and spelling mistakes are also highlighted
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

use Readonly qw(Readonly);
Readonly my $TO_TRIM         => 4;
Readonly my $ACCESS_LEVEL => 1;

use English qw(-no_match_vars $UID);
use File::Basename qw(dirname);
use base qw(Pagesmith::Component Pagesmith::Support::Edit);
use Pagesmith::ConfigHash qw(is_developer);

use Apache2::RequestUtil;
use Apache2::URI ();
use HTML::Entities qw(encode_entities);    ## HTML entity escaping
use HTML::HeadParser;

use Pagesmith::Utils::HTMLcritic;
use Pagesmith::Utils::Spelling;

use Pagesmith::Utils::SVN::Config;
use Pagesmith::Core qw(user_info);
use Pagesmith::ConfigHash qw(server_root get_config docroot is_developer);

my %HEADER_MAP = qw(
  Title              title
  X-Meta-Author      author
  X-Meta-Svn-Id      svn_id
  X-Pagesmith-QrCode    qrcode
  X-Meta-Description description
  X-Meta-Keywords    keywords
  X-Pagesmith-NoSpell   no-spell
  X-Pagesmith-Decor     decoration
);

my @INTERPRET = (
  [ 'Status' , {        q( ) => 'No modifications',
                         'A'  => 'Added',
                         'D'  => 'Deleted',
                         'M'  => 'Modified',
                         'C'  => 'Conflict',
                         'X'  => 'In external repository',
                         'I'  => 'Ignored by SVN',
                        q(?) => 'Not in SVN',
                        q(!) => 'Missing',
                        q(~) => 'Different Type',
                        q(#) => 'Directory not in SVN',
  }, ],
  [ 'Prop modified',  { q( ) => 'No modified properties',
                         'M' => 'Properties modified',
                         'C' => 'Properties conflict',
  }, ],
  [ 'Locked?',        { q( ) => 'Not locked',
                         'L' => 'Locked',
  }, ],
  [ 'History?',       { q( ) => 'No hist scheduled',
                        q(+) => 'Hist scheduled',
  }, ],
  [ 'Switched?',      { q( ) => 'Not switched',
                         'S' => 'Switched',
  }, ],
  [ 'Locked?',        { q( ) => 'Not locked in working copy',
                         'K' => 'Locked in working copy',
  }, ],
  [ 'Tree conflict?', { q( ) => 'No tree conflict',
                         'C' => 'Tree conflict',
  }, ],
  [ q(), { q( ) => q() } ],
  [ 'Up to date?',    { q( ) => 'Yes',
                        q(*) => 'Newer version exists on server',
  }, ],
);

my %actions_by_state = (
  q( ) => [],
  'A'  => [qw(commit)],
  'D'  => [qw(commit)],          ## Can't get at the moment!
  'M'  => [qw(commit revert)],   ## Update/
  'C'  => [qw(revert)],
  q(?) => [qw(add)],             ## File needs to be added before committing!
  q(!) => [qw(revert)],          ## Can't get at the moment!
); ## Can't work with "X","I","~" and "#"

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

sub ajax_message {
  my $self = shift;
  return $self->site_is_editable && $self->user->logged_in ? '<div class="panel"><p class="ajaxwait">Loading information about page</p></div>' : q();
}

sub ajax {
  my $self = shift;
  return $self->click_ajax;
}

sub user {
  my $self = shift;
  return $self->page->user;
}

sub grab_head_data {
  my( $self, $html_page ) = @_;
  if( $html_page =~ m{<head>(.*)</head>}mxs ) {
    my $head_data   = {};
    ( my $head = $1 ) =~ s{<%[^>]+%>}{}mxsg; ## Remove any <% %> tags in head as these break header parser
    return unless $head;
    $head =~ s{(<%)(\s[^>]*\s%>)}{}smx;
    my $head_parser = HTML::HeadParser->new();
    return unless $head_parser->parse($head);
    my $head_info = $head_parser->header;
    if( $head_info ) {
      my @header_fields = $head_info->header_field_names;
      foreach my $key ( @header_fields ) {
        my @Q = $head_info->header( $key );
        push @{$head_data->{ $key }}, $head_info->header( $key );
      }
    }
    return $head_data;
  }
  return;
}

## no critic (Complexity)
sub execute {
  my $self = shift;

  return q() unless $self->site_is_editable;
  return q() unless $self->is_valid_user;
  $self->init_events; ## This is the timer code!

  my $filename = $self->r->filename;
  $self->{'in_edit_mode'} = $self->r->unparsed_uri =~ m{\A/action/Edit_Edit(?:/.*)\Z}mxsi;
  if( $filename =~ m{Component}mxs ) {
    $self->r->parse_uri( $self->page->full_uri );
    $filename = $self->r->uri;
    $self->{'in_edit_mode'} = $filename =~ s{\A/action/Edit_Edit(/.*)?\Z}{$1}mxsi;
    $filename = docroot.$filename;
    $filename .= 'index.html' if $filename =~ m{/\Z}mxs;
  }
  return q() unless -e $filename;
  my $editable = 1;
  $editable = 0 unless $filename =~ m{\A/}mxs; ## Must be an editable page!

  return q() unless $editable;
  ## Get repository name from file!

  ## Initialize variables!

  my $state_strings = [];
  my $actions       = {};

  ## Get the SVN repository details of the file!

  my $repos_details = $self->get_repos_details( $filename );

  return q() unless $repos_details; ## Can't do anything unless in repository root!

  ## Set repository and user!
  return q() unless $self->svn_config->set_repos( $repos_details->{'root'} );   ## Not a valid repository
  return q() unless $self->svn_config->set_user( $self->user->ldap_id );        ## Not a valid user for this repository

  ## Return if user can't update file (this is basic permissions - will later need to check addfile
  ## permissions if file NOT in SVN!

  return q() unless $self->svn_config->can_perform( $repos_details->{'path'}, 'update' );

  my $status_results = $self->run_cmd( [$self->svn_cmd, qw(status --non-interactive -u -v), $filename] );
  my $tabs           = $self->tabs->add_classes('clear');

  my $str            = $self->r->notes->get( 'html' );

  if( $status_results->{'success'} && @{$status_results->{'stdout'}} ) { ## CMD did not fail ....
    my $l_flags = substr $status_results->{'stdout'}[0], 0, scalar @INTERPRET;
    my @tmp_list = split m{}mxs, $l_flags;
    my( $status, $propmod, $locked, $history, $switched, $locked_working, $tree, $blank, $uptodate ) = @tmp_list;

    my $label = exists $INTERPRET[0][1]{ $status } ? $INTERPRET[0][1]{$status} : "Unknown state: $status";

    if( $uptodate eq q(*) ) {
      push @{$state_strings}, 'Not up to date';
      $actions->{ 'update' }++;
    }

    if( $l_flags =~ m{\S}mxs ) {
      my $twocol = $self->twocol;
      foreach my $col (@INTERPRET) {
        my $flag = shift @tmp_list;
        $twocol->add_entry( $col->[0], $col->[1]{$flag} ) unless $flag eq q( );
      }
      $tabs->add_tab( 'edit_status', 'Status - mods', $twocol->render );
    } else {
      $tabs->add_tab( 'edit_status', 'Status - no mods', '<p>No modifications</p>' );
    }
    push @{$state_strings}, $label;
    $self->push_event( 'Got status' );
    my %extra_info;
    if( $repos_details->{'success'} ) {
      %extra_info = (
        'repos_url'   => $repos_details->{'url'},
        'staging_url' => $repos_details->{'root'}.'/staging'.$repos_details->{'part'},
        'live_url'    => $repos_details->{'root'}.'/live'.$repos_details->{'part'},
        'repos_ver'   => $repos_details->{'info'}{'Revision'},
      );
      my $info_twocol = $self->twocol;
      if( $repos_details->{'infarray'} ) {
        foreach( @{$repos_details->{'infarray'}} ) {
          $info_twocol->add_entry( @{$_} );
        }
      }
      $tabs->add_tab( 'edit_info', 'Info', $info_twocol->render );
    }
    ## Now we get the diffs between here / checkout revsion
    my $local_changes = 0;
    if( $status eq 'M' || $status eq 'C' ) {
      $local_changes = 1;
      $self->markup_diffs( $tabs, 'local', 'Local changes',
        [$filename]);
    }
    if( $uptodate eq q(*) ) {
      $self->markup_diffs( $tabs, 'other', 'Other changes',
        [q(-r), qq($extra_info{'repos_ver'}:HEAD), $filename]);
      if( $local_changes ) {
        $self->markup_diffs( $tabs, 'head', 'Diffs to HEAD',
          [q(-r), q(HEAD), $filename]);
      }
    }
    ## Now we get the diffs between checkout revsion / head
    ## Now we get the diffs between here / head

    if( exists $actions_by_state{$status} ) {
      $actions->{$_} ++ foreach @{$actions_by_state{$status}};
      delete $actions->{'add'} unless $self->svn_config->can_perform( $repos_details->{'path'}, 'addfile' );
      my $ll_flags = $self->generate_svn_form_panel( {
        'filename'     => $filename,
        'state'        => $state_strings,
        'actions'      => $actions,
        'info_success' => $repos_details->{'success'},
        'no_staging'   => get_config('Staging') ne 'true',
        %extra_info,
      });
      if( $ll_flags->{'stage'} ) {
        $self->markup_diffs( $tabs, 'stage', 'Diff dev/staging',
          [$extra_info{'staging_url'}, $extra_info{'repos_url'}]);
      }
      if( $ll_flags->{'live_x'} ) {
        $self->markup_diffs( $tabs, 'publish', 'Diff dev/live',
          [$extra_info{'live_url'}, $extra_info{'repos_url'}]);
      }
      if( $ll_flags->{'publish'} ) {
        $self->markup_diffs( $tabs, 'publish', 'Diff staging/live',
          [$extra_info{'live_url'}, $extra_info{'staging_url'}]);
      }

    } else {
      $tabs->add_tab( 'edit_bad-state', 'Bad state', '<p>This is in a state that has to be manually resolved</p>' );
    }
  } else {
    $tabs->add_tab( 'edit_status', 'Status - not in SVN', '<p>This file (and the directory it is in) are not currently in SVN</p>' );
  }




                                                    $self->push_event( 'Finished SVN stuff' );
  $self->add_head_tab(     $tabs );
                                                    $self->push_event( 'Head parsed' );
  $self->add_critic_tab(   $tabs );
                                                    $self->push_event( 'Critic done' );
  $self->add_spelling_tab( $tabs );
                                                    $self->push_event( 'Spelling done' );
  $self->push_output( $tabs->render );
  my $notes = join q(, ), @{$state_strings};
  my $extra_classes = q();
     $extra_classes = ' collapsed' unless keys %{$actions};

  my $caption = qq(<h3>Non editable - $notes);
  if( $editable ) {
    my $link = $self->{'in_edit_mode'} ? '<a href="%s">VIEW</a>' : '<a href="/action/Edit_Edit%s">EDIT</a>';
    $caption = sprintf q(<h3>Editable page - %s - %s</h3>), $notes, sprintf $link, $self->r->uri;
  }

  return $self
    ->unshift_output( $caption ) ## Set the heading...
    ->unshift_output( qq(<div class="panel box-msg collapsible$extra_classes">) )   ## Wrap the div...
    ->push_output(    q(</div>) )                                    ## /Wrap the div...
    ->dump_events                                                    ## Dump to stderr
    ->get_output;                                                    ## Retrieve output
}
## use critic

sub add_head_tab {
  my( $self, $tabs ) = @_;
  my $hi = $self->grab_head_data( $self->r->notes->get( 'html' ) );
  return unless $hi;
  my $html = q();

# Known attributes....
  my $head_twocol = $self->twocol;
  foreach ( sort grep { exists $HEADER_MAP{ $_ } } keys %{$hi} ) {
    $head_twocol->add_entry( $HEADER_MAP{$_}, @{$hi->{$_}} );
    delete $hi->{$_};
  }
  if( $head_twocol->no_of_entries ) {
    $html .= sprintf '<h4>%s</h4>%s', 'Page attributes', $head_twocol->render;
  }

# Links....
  if( exists $hi->{'Link' } ) {
    my @links;
    foreach my $value ( @{$hi->{'Link'}} ) {
      my $link;
      if( $value =~ s{<([^>]+)>}{}mxs ) {
        $link = $1;
        my %attrs;
        while( $value =~ s{;\s+(\w+)="([^"]+)"}{}mxs ) {
          my( $name, $val ) = ($1,$2);
          $attrs{$name} = $val unless $name eq q(/);
        }
        push @links, sprintf '%s (%s)', $link,
          join '; ', map { sprintf '%s="%s"', $_, $attrs{$_} } sort keys %attrs;
      }

    }
    delete $hi->{'Link'};
    if( @links ) {
      my $links_twocol = $self->twocol;
      $links_twocol->add_entry( 'Links' , @links ) ;
      $html .= sprintf '<h4>%s</h4>%s', 'Head links (e.g. CSS)', $links_twocol->render;
    }
  }

# Other attributes
  if( keys %{$hi} ) {
    my $other_twocol = $self->twocol;
    foreach my $key ( sort keys %{$hi} ) {
      $other_twocol->add_entry( $key , @{$hi->{$key }} );
    }
    $html .= sprintf sprintf '<h4>%s</h4>%s', 'Other attributes', $other_twocol->render;
  }
  $tabs->add_tab( 'edit_hd', 'Head block', $html );
  return $self;
}

sub add_critic_tab {
  my( $self, $tabs ) = @_;
  my $critic = $self->r->pnotes( 'critic' );
  my $filename;
  unless( $critic ) {
    my $cleanup;
    if( $self->page->filename =~ m{[.]html\Z}mxgs ) {
      $filename = $self->page->filename;
    } elsif( $self->r->notes->get( 'html' ) ) {
      $filename = $self->page->tmp_filename('html');
      my $flag = open my $fh, '>', $filename;
      if( $flag ) {
        print {$fh} $self->r->notes->get( 'html' ); ## no critic (CheckedSyscalls)
        close $fh; ## no critic (RequireChecked)
        $cleanup = 1;
      } else {
        $filename = q();
      }
    }
    return q() unless $filename;

    $critic = Pagesmith::Utils::HTMLcritic->new( $filename, $ACCESS_LEVEL );
    my $msg    = $critic->check;
    unlink $filename if $cleanup;

    return $tabs->add_tab( 'edit_critic', 'Critic - Error', qq(<p>$msg</p>) ) if $msg;
  }
  unless( $critic->invalid ) {
    return $tabs->add_tab( 'edit_critic', 'Critic - OK ', q(<p>This page is XHTML compliant</p>) );
  }
  my $html = q();
  my @messages = $critic->messages;
  if( @messages > 0 ) {
## no critic (ImplicitNewlines)
    $html = '
<table class="sorted-table">
  <thead>
    <tr>
      <th>Level</th>
      <th>Line</th>
      <th>Col</th>
      <th>Text</th>
    </tr>
  </thead>
  <tbody>';
    foreach( @messages) {
      my $msgs;
      if( $_->{'level'} eq 'Access' ) {
        $msgs = join q(), map { m{\[(\d+[.]\d+[.]\d+[.]\d+)\]:\s+(.*)\Z}mxgs ?
          sprintf '<dt>%s %d: %s</dt><dd>%s</dd>', @{$critic->access_level($1)}, $1, encode_entities($2) :
          sprintf '<dt>*</dt><dd>%s</dd>', $_
        } @{ $_->{'messages'} };
        $msgs = qq(<dl class="twocol">$msgs</dl>);
      } else {
        $msgs = join '<br />', map { encode_entities( $_ ) } @{$_->{'messages'}};
      }
      $html .= sprintf '
    <tr class="tidy-%s">
      <td class="c">%s</td>
      <td class="r">%d</td>
      <td class="r">%d</td>
      <td>%s</td>
    </tr>',
        lc $_->{'level'}, $_->{'level'},
        $_->{'line'}, $_->{'column'},
        $msgs;
    }
    $html .= q(
  </tbody>
</table>);
## use critic
  }
  if( $critic->xml_error ) {
    $html .= sprintf '<h4>XML not well formed</h4><pre>%s</pre>',
      encode_entities( $critic->xml_error );
  }
  my $caption = sprintf 'Critic - %d/%d', $critic->n_errors,$critic->n_warnings;
  return $tabs->add_tab(
    'edit_critic',
    $caption,
    sprintf '<p><strong>Errors %d errors/ %d warnings / %d info/ %d access - %s</strong></p>%s',
    $critic->n_errors,
    $critic->n_warnings,
    $critic->n_info,
    $critic->n_access,
    defined($critic->xml_error) ? 'XML is NOT well-formed' : q(),
    $html,
  );
}

sub add_spelling_tab {
  my( $self, $tabs ) = @_;
  my $str = $self->r->notes->get( 'html' );
  return q() unless $str;
  my $no_spell = $self->r->headers_out->get( 'X-Pagesmith-NoSpell' )||0;
  return q() if $no_spell eq '2';

  my $sp = Pagesmith::Utils::Spelling->new( $no_spell );
  my $return_error = $sp->check_html( $str );

  my $i = 1;
  my $source = join qq(\n),
    map { sprintf '<span class="linenumber">%5d:</span> %s', $i++, $_ }
    split m{\n}mxs, $sp->{'marked_up'} || $self->encode( $str );

  if( $return_error ) {
    $tabs->add_tab('edit_spelling','Source XML error',
      sprintf
      '<p><strong>Unable to check spelling of code - XHTML invalid</strong></p><pre>%s</pre>',
      $source);
  } elsif( $sp->{'total_errors'} ) {
    my $diff = keys %{$sp->{'errors'}};
    my $words = join q(, ),
                 map { $sp->{'errors'}{$_}==1 ? $_: sprintf q(%s (%d)), $_, $sp->{'errors'}{$_} }
                sort { lc($a) cmp lc($b) || $a cmp $b }
                keys %{$sp->{'errors'}};
    my $caption = sprintf 'Spelling %d/%d', $sp->{'total_errors'}, $diff;
    $tabs->add_tab('edit_spelling',$caption, sprintf
      '<p><strong>%d spelling mistakes (%d words)</strong></p><p>%s</p><pre style="line-height: 1em; font-size: 0.8em">%s</pre>',
      $sp->{'total_errors'}, $diff, $words, $source);
  } else {
    $tabs->add_tab('edit_spelling','Spelling OK',
      sprintf '<p>Please note - this only checks spelling and not grammar and context!</p><pre style="line-height: 1em; font-size: 0.8em">%s</pre>',
      $source );
  }
  return $self;
}


sub trim_head {
  my( $self, $str ) = @_;
  return substr $str, $TO_TRIM;
}

sub markup_diff_block {
  my( $self, $index_ref, $lines_ref ) = @_;
  return sprintf '<h4>%s</h4><pre>%s</pre>', $index_ref->[0],
    join qq(\n), map { sprintf
        $_->[0] eq q(+) ? q(<span class="svn_added">%s %s</span>)
      : $_->[0] eq q(-) ? q(<span class="svn_removed">%s %s</span>)
      :                   q(<span class="svn">%s %s</span>)
      , $_->[0], $self->encode( $_->[1] )
      ;
    } @{$lines_ref};
}

sub markup_diffs {
  my( $self, $tabs, $tab_key, $tab_label, $params ) = @_;
  my $diff_results = $self->run_cmd( [$self->svn_cmd, qw(diff --non-interactive), @{$params} ] );
  my @diff_index;
  my @diff_lines;
  my @head_block;
  my $diff_output = q();
  foreach my $line ( @{$diff_results->{'stdout'}} ) {
    last if $line eq q();
    if( $line =~ m{\A[@][@]\s-(\d+),(\d+)\s[+](\d+),(\d+)\s[@][@]\Z}mxs ) {
      if( @diff_index ) {
        $diff_output .= $self->markup_diff_block( \@diff_index, \@diff_lines );
      }
      @diff_index = ( $line, $1, $2, $3, $4 );
      @diff_lines = ();
      next;
    }
    if( @diff_index ) {
      my $init = substr $line, 0, 1, q();
      last unless $init eq q( ) || $init eq q(+) || $init eq q(-);
      push @diff_lines, [ $init, $line ];
    } else {
      push @head_block, $line;
    }
  }
  $diff_output .= $self->markup_diff_block( \@diff_index, \@diff_lines ) if @diff_index;

  return unless $diff_output;

  my($index,$blank,$old,$new) = @head_block;
  ## no critic (LongChainsOfMethodCalls)
  $tabs->add_tab( 'edit_'.$tab_key, $tab_label,
    $self->twocol
         ->add_entry( 'From', $self->trim_head( $old ) )
         ->add_entry( 'To',   $self->trim_head( $new ) )
         ->render.  $diff_output );
  ## use critic
  return;
}

sub generate_svn_form_panel {
  my( $self, $params ) = @_;

  $self->push_event( 'Got info' );

  my $flags = {};
  if( $params->{'info_success'} ) { ## Must be in trunk!

    if( $params->{'no_staging'} ) {
      my $live_diff_results = $self->run_cmd( [$self->svn_cmd, qw(diff --non-interactive --summarize),
        $params->{'repos_url'}, $params->{'live_url'} ] );
      if( @{$live_diff_results->{'stdout'}} && $live_diff_results->{'stdout'}[0] =~ m{\AM}mxs ) {
        push @{$params->{'state'}}, 'Live not up to date';
        $params->{'actions'}{ 'publish' }++;
        $flags->{'live_x'}++;
      } else {
        push @{$params->{'state'}}, 'Not on live';
        $params->{'actions'}{ 'publish' }++;
      }
    } else {
      my $staging_diff_results = $self->run_cmd( [$self->svn_cmd, qw(diff --non-interactive --summarize),
        $params->{'repos_url'}, $params->{'staging_url'} ] );

      $self->push_event( 'Got staging' );
      if( $staging_diff_results->{'success'} ) {
        if( @{$staging_diff_results->{'stdout'}} && $staging_diff_results->{'stdout'}[0] =~ m{\AM}mxs ) {
          push @{$params->{'state'}}, 'Staging not up to date';
          $params->{'actions'}{ 'stage' }++;
          $flags->{'stage'}++;
        }
        my $live_diff_results = $self->run_cmd( [$self->svn_cmd, qw( diff --non-interactive --summarize),
          $params->{'staging_url'}, $params->{'live_url'} ] );
        $self->push_event( 'Got live' );
        if( $live_diff_results->{'success'} ) {
          if( @{$live_diff_results->{'stdout'}} && $live_diff_results->{'stdout'}[0] =~ m{\AM}mxs ) {
            push @{$params->{'state'}}, 'Live not up to date';
            $params->{'actions'}{ 'publish' }++;
            $flags->{'publish'}++;
          }
        } else {
          push @{$params->{'state'}}, 'Not on live';
          $params->{'actions'}{ 'publish' }++;
        }
      } else {
        push @{$params->{'state'}}, 'Not on staging';
        $params->{'actions'}{ 'stage' }++;
      }
    }
  }
  if( keys %{$params->{'actions'}} ) {
    ( my $url = $self->r->uri ) =~ s{/index[.]html\Z}{/}mxs;
    ## no critic (ImplicitNewlines)
    $self->push_output( sprintf '
<form action="/action/Edit_Edit%s" method="post">
  <dl>
    <dt>Action:</dt>  <dd><select name="act">%s</select></dd>
    <dt>Message:</dt> <dd><textarea rows="10" cols="80" name="message" style="width: 98%%"></textarea></dd>
  </dl>
  <div><input type="submit" value="Go &raquo;" /></div>
</form>',
      $self->encode( $url ),
      join q(), map { sprintf '<option value="%s">%s</option>', $_, $self->encode( $_ ) } sort keys %{$params->{'actions'}} );
    ## use critic
  }
  return $flags;
}

1;
