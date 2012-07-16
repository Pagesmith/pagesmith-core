package Pagesmith::Pod2XHTML;

## Converts POD to XHTML...
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

use Data::Dumper;
use HTML::Entities qw(encode_entities);
use Pod::Simple::SimpleTree;

sub new {
  my $class = shift;
  my $self  = {
    'root'    => '/www/www-trunk',
    'parser'  => q(),
    'infile'  => q(),
    'outfile' => q(),
    'data'    => q(),
    'html'    => q(),
    'title'   => q(),
  };
  bless $self, $class;
  return $self;
}

sub HTML {
  my $self = shift;
  return $self->{'html'};
}

##no critic (BuiltinHomonyms)
sub dump {
  my $self = shift;
  return Data::Dumper->new( [$self->{'data'}], ['data'] )->Indent(1)->Terse(1)->Dump();
}
##use critic (BuiltinHomonyms)

sub module {
  my($self,$module,$pars) = @_;
  $pars ||= {};
  if ( exists $pars->{'infile'} ) {
    $self->{'infile'} = $pars->{'infile'};
  } else {
    ( my $file = $module ) =~ s{::}{/}mxgs;
    $self->{'infile'} = "$self->{'root'}/lib/$file.pm";    ## Use safe code from components!
  }
  return;
  ## Check existance!
}

sub parse {
  my $self = shift;
  $self->{'parser'} ||= Pod::Simple::SimpleTree->new();
  $self->{'data'} = $self->{'parser'}->parse_file( $self->{'infile'} )->root;
  return 'No pod' unless @{ $self->{'data'} };

  my ( $type, $global_pars, @entryies ) = @{ $self->{'data'} };
  $self->{'html'} = q();
  foreach my $entry (@entries) {
    my ( $e_type, $pars, @entry ) = @{$entry};
    if ( $e_type eq 'over-text' ) {
      $self->{'html'} .= $self->_render_list( $pars, @entry );
    } elsif ( $e_type =~ m{\Ahead(\d+)}mxs ) {
      my $t = $self->_render_block( 'h' . ( $1 + 1 ), @entry );
      $self->{'title'} ||= $t =~ m{<h(\d+)>(.*)</h\1>}mxs ? $2 : q();
      $self->{'html'} .= $t;
    } elsif ( $e_type eq 'Para' ) {
      $self->{'html'} .= $self->_render_block( 'p', @entry );
    }
  }
  return;
}

sub _render_list {
  my($self,$pars,@vars) = @_;
  my $t    = $vars[0][2];
  my ( $type, $subtype ) =
      $t =~ m{\A\d+\)}mxs   ? qw( ol decimal )
    : $t =~ m{\AA\)}mxs     ? qw( ol upper-alpha )
    : $t =~ m{\AI\)}mxs     ? qw( ol upper-roman )
    : $t =~ m{\Aa\)}mxs     ? qw( ol lower-alpha )
    : $t =~ m{\Ai\)}mxs     ? qw( ol lower-roman )
    : $t =~ m{\A[-\.]\s}mxs ? qw( ul disc )
    : $t =~ m{\Ao\s}mxs     ? qw( ul circle )
    : $t =~ m{\A\#\s}mxs    ? qw( ul square )
    :                       qw( ul none )
    ;
  my $html = qq(<$type style="list-style-type: $subtype">\n);
  foreach my $ar (@vars) {
    my ( $x, $params, @ar ) = @{$ar};
    if ( $x eq 'over-text' ) {
      $html .= "<li>\n" . $self->_render_list( $params, @ar ) . "</li>\n";
    } else {
      $ar[0] =~ s{^((\d+|A|I|a|i)\)|[-\.o\#])\s}{}mxs unless ref $ar[0];
      $html .= $self->_render_block( 'li', @ar );
    }
  }
  $html .= "</$type>\n";
  return $html;
}

sub _render_block {
  my($self,$type,@vars) = @_;
  my $html = "<$type>";
  foreach (@vars) {
    $html .= $self->_render_span($_);
  }
  $html .= "</$type>\n";
  return $html;
}

sub _render_span {
  my ($self, $x ) = @_;

  return encode_entities($x) unless ref $x;
  my ( $type, $pars, @x ) = @{$x};
  my ( $a, $b ) =
      $type eq 'B' ? ( 'strong', q() )
    : $type eq 'I' ? ( 'em',     q() )
    : $type eq 'F' ? ( 'span',   ' class="file"' )
    : $type eq 'C' ? ( 'code',   q() )
    : $type eq 'L' ? ( 'a',      $self->_link($pars) )
    :                ( 'span',   ' class="error"' );
  return qq(<$a$b>) . join( q(), map { $self->_render_span($_) } @x ) . "</$a>";
}

sub _link {
  my ($self,$pars) = @_;
  return
      $pars->{'type'} eq 'url' ? sprintf( ' href="%s"', encode_entities( $pars->{'to'}[2] ) )
    : $pars->{'type'} eq 'pod' ? sprintf( ' href="%s"', $self->_pod_url( $pars->{'to'}[2] ) )
    :                            ' href="#"';
}

sub _pod_url {
  my($self,$module) = @_;
  return encode_entities("/developer/docs/perl/lib/$module.html");
}

1;
