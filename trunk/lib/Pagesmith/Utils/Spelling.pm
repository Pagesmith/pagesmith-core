package Pagesmith::Utils::Spelling;

## Support class to spell check XHTML pages
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

## There are a few buglets to solve - mainly to do with XHTML entities (e.g. nbsp)

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use XML::Parser;
use Text::Aspell;
use HTML::Entities qw(encode_entities);
use English qw($EVAL_ERROR -no_match_vars);
use Pagesmith::ConfigHash qw(server_root);
use File::Spec;

sub new {
  my( $class, $no_spell ) = @_;

  my $speller;
  unless( $no_spell ) {
    $speller = Text::Aspell->new;
    $speller->set_option('sug-mode','slow');
    $speller->set_option('encoding','utf-8');
    $speller->set_option('personal', File::Spec->catfile( server_root, qw(config aspell.en_GB.pws)   ) );
    $speller->set_option('repl',     File::Spec->catfile( server_root, qw(config aspell.en_GB.prepl) ) );
    $speller->set_option('lang',    'en_GB-ize');
  }
  my $self = {
    'xml_parser'    => XML::Parser->new('Style'=>'Tree','ErrorContext'=>1,'ProtocolEncoding'=>'UTF-8','NoExpand'=>1),
    'spell_checker' => $speller,
    'check_attr'    => { map { ($_,1) } qw(title alt content summary) },
    'marked_up'     => q(),
    'seen'          => {},
    'directives'    => [],
    'errors'        => {},
    'suggestions'   => {},
    'total_errors'  => 0,
  };

  bless $self,$class;
  return $self;
}

sub check_html {
  my( $self, $html ) = @_;
  $html =~ s{<%(.*?)%>}{push @{$self->{'directives'}}, [ '', $1 ];'<directive />'}mxges;
  $html =~ s{&(\w+);}{{entity:$1}}mxgs;
  $html =~ s{{entity:(amp|gt|lt|quot)}}{&$1;}mxgs;
  my $res = eval {
    my $tree = $self->{'xml_parser'}->parse( $html );
    my( $tag, $contents ) = @{$tree};
    my $attr = {};
    if( ref($contents->[0]) eq 'HASH' ) {
      $attr = shift @{$contents};
    }
    $self->_xml( $tag, $attr, $contents );
  };
  return $EVAL_ERROR;
}

sub check {
  my( $self, $word ) = @_;
  unless( exists $self->{'seen'}{$word} )  {
    if( $word =~ m{\A\d+(th|st|nd|rd|am|pm)\Z}mxs || $word =~ m{\A[A-Z0-9]+\Z}mxs ) {
      $self->{'seen'}{$word} = 1;
    } else {
      $self->{'seen'}{$word} = $self->{'spell_checker'}->check( $word );
    }
    unless( $self->{'seen'}{$word} ) {
      my @suggestions = $self->{'spell_checker'}->suggest( $word );
      @suggestions = 'NO SUGGESTIONS' unless @suggestions;
      $self->{'suggestions'}{$word} = join ', ', @suggestions;
    }
  }
  unless( $self->{'seen'}{$word} ) {
    $self->{'total_errors'}++;
    $self->{'errors'}{$word}++;
  }
  return $self->{'seen'}{$word};
}

sub _spell_check {
  my( $self, $string ) = @_;
  unless( $self->{'spell_checker'} ) {
    my $ret = { 'flag' => 0, 'marked_up' => encode_entities($string) };
    return $ret;
  }
  my @Q = split m{([a-z0-9]+)}mxis, $string;
  my $result = q();
  my $flag = 0;
  foreach(@Q) {
    if( m{[A-Z0-9]}mxis ) {
      my $f = $self->check( $_ );
      if( $f ) {
        $result .= encode_entities($_);
      } else {
        $flag=1;
        $result .= sprintf q(<span class="spelling" title="%s">%s</span>),
          $self->{'suggestions'}{$_}, encode_entities($_);
      }
    } else {
      $result .= encode_entities($_);
    }
  }
  my $ret = { 'flag' => $flag, 'marked_up' => $result };
  return $ret;
}

sub skippable {
  my( $self, $token ) = @_;
  return 1 if $token =~ m{\A(["']?-[-\w]+=)?([-\w\.]+)\@([-\w]+\.)+\w+["']?\Z}mxs;
# relative path...
  return 1 if $token =~ m{\A(["']?-[-\w]+=)?([-\w\.]+/)+["']?\Z}mxs;
  return 1 if $token =~ m{\A(["']?-[-\w]+=)?([-\w\.]+/)+([-\w\.]+|[-\w\.]+\.\w{2,5})?["']?\Z}mxs;
# file path (absolute/web)
  return 1 if $token =~ m{\A(["']?-[-\w]+=)?(https?:)?/.*(\.\w{2,5}|/)["']?\Z}mxs;
  return 1 if $token =~ m{\A(["']?-[-\w]+=)?/\w+["']?\Z}mxs;
# file (relative - no path)
  return 1 if $token =~ m{\A(["']?-[-\w]+=)?[-\w]+\.\w{2,5}["']?\Z}mxs;

  return 0;
}

sub html_attr {
  my( $self, $k, $v ) = @_;
  return sprintf ' <span class="html_attr">%s=""</span>', $k if $v eq q();
  return sprintf ' <span class="html_attr">%s="<span class="html_value">%s</span>"</span>', $k, $v;
}

sub _xml {
  my( $self, $tag, $attr, $contents ) = @_;
  if( $tag eq 'entity' ) {
    $self->{'marked_up'} .= qq(<span class="html_entity">&amp;$attr->{'attr'};</span>);
    return;
  }
  if( $tag eq 'directive' ) {
    ## We need to parse the first directive on the list...
    my $t = shift @{$self->{'directives'}};
    my $string = $t->[1];
    if( $string =~ s{\A(~?\s+\w+(::\w+)*\s+)}{}mxs ) {
      $self->{'marked_up'} .= qq(<span class="directive">&lt;%$1);
    }
    my @tokens = split m{(\s+)}mxs, $string;
    foreach my $token ( @tokens )  {
      if( $token =~ m{\S}mxs ) {
        if( $self->skippable( $token ) ) {
          $self->{'marked_up'} .= encode_entities( $token );
        } else {
          my $res = $self->_spell_check( $token );
          $self->{'marked_up'} .= $res->{'marked_up'};
        }
      } else {
        $self->{'marked_up'} .= $token;
      }
    }
    $self->{'marked_up'} .= '%&gt;</span>';
    return;
  }
  my $attr_html = q();
  foreach my $k ( sort keys %{$attr} ) {
    if( $self->{'check_attr'}{$k} ) {
      ## Spellcheck the attribute...
      my $res = $self->_spell_check( $attr->{$k} );
      $attr_html .= $self->html_attr( $k, $res->{'marked_up'} );
    } else {
      $attr_html .= $self->html_attr( $k, $attr->{$k} );
    }
  }

  if( ! @{$contents} || $tag eq 'source' ) {
    ## Self closing tag...
    $self->{'marked_up'} .= sprintf '<span class="html_tag">&lt;%s%s /&gt;</span>', $tag, $attr_html;
    return;
  }
  $self->{'marked_up'} .= sprintf '<span class="html_tag">&lt;%s%s&gt;</span>', $tag, $attr_html;

  while( my( $xml_tag, $sub_contents ) = splice @{$contents},0,2 ) {
    if($xml_tag eq '0' ) {
      if( $sub_contents =~ m{\S}mxs ) {
      ## Check the spelling of the text....
        my $res = $self->_spell_check( $sub_contents );
        $self->{'marked_up'} .= $res->{'marked_up'};
      } else {
        $self->{'marked_up'} .= $sub_contents;
      }
    } else {
      my $sub_attr = {};
      $sub_attr = shift @{$sub_contents} if  ref($sub_contents->[0]) eq 'HASH';
      $self->_xml( $xml_tag, $sub_attr, $sub_contents );
    }
  }
  $self->{'marked_up'} =~ s{\{entity:(\w+)\}}{<span class="html_entity">&amp;$1;</span>}mxgs;
  $self->{'marked_up'} .= sprintf
   '<span class="html_tag">&lt;/%s&gt;</span>', $tag;
  return;
}

1;
