package Pagesmith::Component::Developer::Documentation;

## Insert a APR variable content into the page
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

use base qw(Pagesmith::Component::Markedup);

use HTML::Entities qw(encode_entities);    ## HTML entity escaping
use English qw($EVAL_ERROR $INPUT_RECORD_SEPARATOR -no_match_vars);

use Readonly qw(Readonly);
Readonly my $ACCESS_LEVEL => 1;


sub _cache_key {
  my $self = shift;
  return;
}

sub _relative_to_serverroot {
  my $self = shift;
  return 1;
}

sub execute {
  my $self = shift;
  my( $module_name, $module_file ) = $self->pars;

  my $err = $self->check_file($module_file);

  return $err if $err;

  return $self->_error( 'Forbidden - could not open file: ' . encode_entities($module_file) )
    unless open my $fh, '<', $self->filename;
  my @lines = <$fh>;
  close $fh; ## no critic (RequireChecked)

  my @l;
  my @sections;
  my $flag = 0;
  foreach my $line ( @lines ) {
    chomp $line;
    if( $line =~ m{\A__END__}mxs ) {
      $flag = 1;
      next;
    }
    next unless $flag;
    if( $line =~ m{\Ah3\.\s+(.*)}mxs ) {
      if( @sections ) {
        $sections[-1]->{'content'} = [ @l ];
        @l = ();
      }
      push @sections, { 'title' => $1 };
    } else {
      push @l, $line;
    }
    $sections[-1]->{'content'} = [ @l ] if @sections;
  }

  my $html = sprintf '<h2>%s</h2>', encode_entities( $module_name );
  foreach my $sec (@sections) {
    $html .= sprintf qq(\n\n<h3 class="keep">%s</h3>%s),
      encode_entities( $sec->{'title'} ),
      $self->_render( $sec->{'content'} );
  }
  return $html;
}

sub _render {
  my( $self,  $content_ref ) = @_;
  my $current_list = [];
  my $html = q();
  my $flag = 0;
  while( @{$content_ref} ) {
    my $line = shift @{$content_ref};
    ## no critic (CascadingIfElse)
    if( $line =~ m{\A<%}mxs) {
      $html .= "\n<pre>".encode_entities($line)."\n";
      while( @{$content_ref} ) {
        my $line_x = shift @{$content_ref};
        if( $line_x =~ m{\A%>}mxs ) {
          $html .= encode_entities($line_x);
          last;
        }
        $html .= encode_entities($line_x)."\n";
      }
      $html .= '</pre>';
    } elsif( $line =~ m{\A\*\s+(.*)}mxs ) {
      $html .="\n<ul>  \n  <li>\n    ".encode_entities( $1 );
      $flag = 1;
      while( @{$content_ref} ) {
        my $line_x = shift @{$content_ref};
        if( $line_x =~ m{\A\s*\Z}mxs ) {
          $html .= "\n  </li>" if $flag == 1;
          $flag = 0;
        } elsif( $flag == 0 && $line_x =~ m{\A\*\s*(.*)}mxs ) {
          $html .= "\n  <li>\n    ".encode_entities( $1 );
          $flag = 1;
        } elsif( $flag == 0 ) {
          unshift @{$content_ref}, $line; ## Put the line back!
          last;
        } else {
          $line_x =~ s{\A\s+}{}mxs;
          $html .= qq(\n    ).encode_entities( $line_x );
        }
      }
      $html .= "\n  </li>" if $flag;
      $html .= "\n</ul>";
      $flag = 0;
    } elsif( $line =~ m{\A\s*\Z}mxs ) {
      $html .= '</p>' if $flag == 1;
      $flag = 0;
    } elsif( $flag ) {
      $html .= q(  ).encode_entities( $line )."\n";
    } else {
      $flag = 1;
      $html .= "\n<p>\n  ".encode_entities( $line )."\n";
    }
    ## use critic
  }
  if( $flag == 1 ) {
    $html .= '</p>';
  }
  return $html;
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
