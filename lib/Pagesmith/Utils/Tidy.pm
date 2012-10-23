package Pagesmith::Utils::Tidy;

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

use English qw(-no_match_vars $UID $EVAL_ERROR);
use Carp qw(carp);
use Readonly qw(Readonly);
Readonly my $LINE_LENGTH => 130;

use HTML::Tidy;
use Encode::Unicode;

sub new {
  my ($class, @pars ) =@_;
  my $self  = {
    '_h'    => undef,
    '_flag' => @pars ? $pars[0] : 1,
  };
  bless $self, $class;
  return $self;
}

sub h {
  my $self = shift;
  $self->{'_h'} = HTML::Tidy->new( {
    'wrap'                => $LINE_LENGTH,
#    'hide-comments'       => 1,
    'output_xhtml'        => 1,
    'indent'              => 1,
    'doctype'             => 'omit',
    'enclose-block-text'  => $self->{'_flag'},
    'enclose-text'        => $self->{'_flag'},
    'accessibility-check' => 0,
    'char-encoding'       => 'utf8',
    'numeric-entities'    => 1,
    'preserve-entities'   => 1,
    'merge-divs'          => 0,
    'wrap-attributes'     => 0,
    'tidy-mark'           => 0,
  } ) unless defined $self->{'_h'};
  return $self->{'_h'};
}

sub tidy {
  my $self = shift;
  my $html = shift;
  my $new_html = eval { $self->h->clean(${$html}); };

  carp "ERROR RUNNING tidy: $EVAL_ERROR" if $EVAL_ERROR;

  $new_html =~ s{<h(\d)>\s+(.*?)\s+</h\1>}{<h$1>$2</h$1>}mxgs;    ## Replace the <hn>\n...\n</hn> with <hn>...</hn>
  $new_html =~ s{<html[^>]+>}{<html>}mxs;                         ## Strip out added html tag attributes

  return \$new_html;
}

sub fragment {
  my $self = shift;
  my $html = shift;
  my $new_html;
  my $rv = eval { $new_html = $self->h->clean(${$html}); };

  carp "ERROR RUNNING fragment: $EVAL_ERROR" if $EVAL_ERROR;

  $new_html =~ s{<body>(.*)</body>}{$1}mxs;                       ## Remove the added body tags!

  return \$new_html;
}

1;
