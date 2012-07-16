package Pagesmith::Utils::Validator::XHTML;

## HTML validation class
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

##no critic (CommentedOutCode)
### HTML validator class
###
### Used to validate a subset of XHTML to make sure that code is both DOM safe and clear of any issues
### with respect to inserting script tags etc.
###
### Usage: my $valid = new Pagesmith::Utils::Validator::XHTML->new( 'set' ); my $error = $valid->validator( $string );
###
### Returns an error message indicating the first error found
###
### 'set' can currently be one of "no-tags" - just checks for valid entities and that there are no tags;
### "in-line" - only allows in-line elements; "normal" - allows selection of block level tags
##use critic (CommentedOutCode)

my $sets = {};

### Package global variable $sets defines the different groups of tags allowed

$sets->{'no-tags'} = {
  'ent' => '&(amp|#x26|lt|#x3C|gt|#x3E|quot|#x22|apos|#x27);',
  'ats' => {},
  'nts' => {},
};

$sets->{'in-line'} = {
  'ent' => $sets->{'no-tags'}{'ent'},
  'ats' => { map {($_,1)} qw(class title id style) },
  'nts' => {
    'img'    => { 'rt' => 1, 'tx' => 0, 'at' => {map {($_,1)} qw(src alt title)}, 'tg' => {} },
    'a'      => { 'rt' => 1, 'tx' => 1, 'at' => {map {($_,1)} qw(href name rel)}, 'tg' => {map {($_,1)} qw(img span em strong)} },
    'strong' => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em)       } },
    'em'     => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a    strong)} },
    'span'   => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong)} },
  },
};
$sets->{'normal'} = {
  'ent' => $sets->{'no-tags'}{'ent'},
  'ats' => $sets->{'in-line'}{'ats'},
  'nts' => {
    %{ $sets->{'in-line'}{'nts'} },
    'p'  => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong)           } },
    'li' => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p)} },
    'dt' => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p)} },
    'dd' => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p)} },
    'ol' => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(li)   } },
    'ul' => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(li)   } },
    'dl' => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(dd dt)} },
  },
};
$sets->{'extended'} = {
  'ent' => $sets->{'no-tags'}{'ent'},
  'ats' => $sets->{'in-line'}{'ats'},
  'nts' => {
    %{ $sets->{'normal'}{'nts'} },
    'img'    => { 'rt' => 1, 'tx' => 0, 'at' => {map {($_,1)} qw(src alt title usemap ismap width height)}, 'tg' => {} },
    'a'      => { 'rt' => 1, 'tx' => 1, 'at' => {map {($_,1)} qw(href name rel)}, 'tg' => {map {($_,1)} qw(img span em strong map b i)} },
    'b'      => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em b i)       } },
    'i'      => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a    strong b i)} },
    'br'     => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {} },
    'strong' => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em b i)       } },
    'em'     => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a    strong b i)} },
    'span'   => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong b i)} },
    'div'    => { 'rt' => 1, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p table div map b i br)} },
    'li'     => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p table div map b i br)} },
    'dt'     => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p table div map b i br)} },
    'dd'     => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(img span a em strong ul ol dl p table div map b i br)} },
    'table'  => { 'rt' => 1, 'tx' => 0, 'at' => {}, 'tg' => {map{($_,1)} qw(thead tbody tfoot tr) }},
    'thead'  => { 'rt' => 0, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(tr) }},
    'tbody'  => { 'rt' => 0, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(tr) }},
    'tfoot'  => { 'rt' => 0, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(tr) }},
    'tr'     => { 'rt' => 0, 'tx' => 0, 'at' => {}, 'tg' => {map {($_,1)} qw(td th) }},
    'td'     => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(table p pre dl ul ol div img span a em strong map b i br) }},
    'th'     => { 'rt' => 0, 'tx' => 1, 'at' => {}, 'tg' => {map {($_,1)} qw(table p pre dl ul ol div img span a em strong map b i br) }},
    'map'    => { 'rt' => 0, 'tx' => 0, 'at' => {map{($_,1)} qw(name)}, 'tg' => {map {($_,1)} qw(area) }},
    'area'   => { 'rt' => 0, 'tx' => 0, 'at' => {map{($_,1)} qw(shape coords href alt)}, 'tg' => {} },
  },
};

sub new {
  my $class = shift;
  my $self = { 'set' => shift || 'normal' };
  bless $self, $class;
  return $self;
}

sub info {
  my( $self, $k ) = @_;
  return $sets->{ $self->{'set'} }{$k};
}

sub trim {
  my( $self, $string ) = @_;
  $string =~ s{\s+}{ }mxgs;
  $string =~ s{\A\s}{}mxgs;
  $string =~ s{\s\Z}{}mxgs;
  return $string;
}

##no critic (ExcessComplexity)
sub validate {
  my( $self, $string ) = @_;
## Tokenize string;
  my @a;
  foreach my $w ( split m{(?=<)}mxs, $string ) {
    if( $w =~m{\A<}mxs ) {
      my ($x,$y) = $w =~ m{\A([^>]+>)([^>]*)\$}mxs;
      if( $x ) {
        push @a, $x;
        push @a, $y if $y =~ m{\S}mxs;
      } else {
        return 'Not well formed: "'.$self->trim($w).q(");
      }
    } elsif( $w =~ m{>}mxs ) {
      return 'Not well formed: "'.$self->trim($w).q(");
    } else {
      push @a, $w;
    }
  }
  my @stk;
  my $ent_regexp = $self->info('ent');
  foreach my $w ( @a ) {
    my $LN = $stk[0];
    if( $w =~ m{\A<}mxs ) {
      if( $w =~ m{</(\w+)>}mxs ) { # We have a close tag...
        if( @stk ){
          my $LAST = shift @stk;
          return qq(Mismatched tag "/$1" != "$LAST") if $LAST ne $1;
        } else {
          return qq(Attempt to close too many tags "/$1");
        }
      } elsif( $w =~ m{<(\w+)(.*?)(/?)>}mxs ) { ## tag node
        my $TN  = $1;
        my $ATS = $2;
        my $SCL = $3 eq q(/) ? 1 : 0;
        return qq(Non lower-case tag: "$TN") if $TN=~m{[A-Z]}mxs;
        return qq(Tag "$TN" not allowed)              unless $self->info('nts')->{$TN};
        return qq(Tag "$TN" not allowed in "$LN")     if  $LN && !$self->info('nts')->{$LN}{'tg'}{$TN};
        return qq(Tag "$TN" not allowed at top level) if !$LN && !$self->info('nts')->{$TN}{'rt'};
        unshift @stk, $TN unless $SCL;
        next unless $ATS;
        while( $ATS =~ s{\A\s+(\w+)\s*=\s*"([^"]*)"}{}mxs ) {
          my $AN = $1;
          my $vl = $2;
          return qq(Non lower case attr name "$AN" in tag "$TN") if $AN =~ m{[A-Z]}mxs;
          return qq(Attr "$AN" not valid in tag "$TN")           unless $self->info('ats')->{$AN} || $self->info('nts')->{$TN}{'at'}{$AN};
          foreach my $e ( split m{(?=&)}mxs, $vl ) {
            return q(Unknown entity ").$self->trim($e).qq(" in attr "$AN" in tag"$TN") if substr($e,0,1) eq q(&) && $e !~ m{$ent_regexp}mxs;
          }
        }
        return qq(Problem with tag "$TN"'s attrs ($ATS).) if $ATS=~m{\S}mxs;
      } else {
        return qq(Malformed tag "$w");
      }
    } else { ## text nodfe
      return qq(No raw text allowed in "$LN") if $LN && !$self->info('nts')->{$LN}{'rt'};
      foreach my $e ( split m{(?=&)}mxs, $w ) {
        return q(Unknown entity ").$self->trim($e).q(") if substr($e,0,1) eq q(&) && $e !~ m{$ent_regexp}mxs;
      }
    }
  }
  return @stk ? qq(Unclosed tags "@stk") : undef;
}
##use critic (ExcessComplexity)

1;
