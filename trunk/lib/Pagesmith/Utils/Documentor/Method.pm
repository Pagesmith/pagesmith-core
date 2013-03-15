package Pagesmith::Utils::Documentor::Method;

##g
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

use base qw(Pagesmith::Utils::Documentor);

use Pagesmith::HTML::TwoCol;
use Const::Fast qw(const);
use HTML::Entities qw(encode_entities);
use Syntax::Highlight::Perl::Improved;

const my $OPT_MAP    => { q(?) => ' (optional)', q(+) => ' (multiple)', q(*) => ' (multiple optional)' };
const my $CLASSES    => { qw(set Set get Get setter Set getter Get getsetter Acc accessor Acc acc Acc) };
const my $CLASS_DESC => { 'Set' => 'Setter', 'Get' => 'Getter', 'Acc' => 'Accessor', 'Con' => 'Constructor', 'Y' => 'Method', q(-) => 'Function' };

sub new {
#@params (class) (string method name) (Pagesmith::Utils::Documentor::File source file) (string package name)
  my( $class, $name, $file, $package ) = @_;
  my $self = {
    'name'        => $name,
    'start'       => undef,
    'class'       => undef,
    'end'         => undef,
    'file'        => $file,
    'description' => [],
    'return_type' => undef,
    'return_desc' => undef,
    'parameters'  => [],
    'documented'  => 0,
    'notes'       => [],
    'package'     => $package,
  };
  bless $self, $class;
  return $self;
}

sub name {
#@params (self)
#@return (string) method name
  my $self = shift;
  return $self->{'name'};
}

sub package_name {
#@params (self)
#@return (string) method name
  my $self = shift;
  return $self->{'package'};
}

sub file {
#@params (self)
#@return (Pagesmith::Utils::Documentor::File) attached file object
  my $self = shift;
  return $self->{'file'};
}

sub start {
#@params (self)
#@return (int) line number for start of method
  my $self = shift;
  return $self->{'start'};
}

sub set_start {
#@params (self) (int line number)
#@return (self)
## Set start line number
  my( $self, $start ) = @_;
  return $self->{'start'} = $start;
}

sub documented {
#@params (self)
#@return (int) returns true if there is '#@/##' documentation in module
## Test to see if method has been documented
  my $self = shift;
  return $self->{'documented'};
}

sub is_documented {
#@params (self)
#@return (string) yes if method id documented
## Test to see if method has been documented
  my $self = shift;
  return $self->{'documented'} ? 'Y' : q(-);
}

sub class {
#@params (self)
#@return (string) class of method
## Return class of method (accessor/getter/setter)
  my $self = shift;
  return $self->{'class'};
}

sub set_class {
#@params (self) (string class)
#@return (self)
## Sets class of method (accessor/getter/setter)
  my( $self, $class ) = @_;
  return $self->{'class'} = exists $CLASSES->{$class} ? $class : undef;
}

sub is_method {
#@params (self)
#@return (string) yes if method id documented
## Test to see if subtroutine is an object "method" OR just a function!
  my $self = shift;
  return q(.)   unless $self->number_parameters;
  if( $self->{'parameters'}[0]{'type'} eq 'self' ) {
    return $CLASSES->{$self->{'class'}} if $self->{'class'};
    return 'Y';
  }
  return 'Con' if $self->{'parameters'}[0]{'type'} eq 'class';
  return q(-);
}

sub method_desc {
#@params (self)
#@return (string) Type of method - one of Getter, Setter, Accessor, Method, Function, ..
## Long form of the function "class"...
  my $self = shift;
  my $method = $self->is_method;
  return $CLASS_DESC->{$method} if exists $CLASS_DESC->{$method};
  return 'Unknown';
}

sub set_documented {
#@params (self)
#@return (self)
## Set flag to say method is documented
  my $self = shift;
  return $self->{'documented'} = 1;
}

sub clear_documented {
#@params (self)
#@return (self)
## Clear flag to say method is not documented
  my $self = shift;
  return $self->{'documented'} = 0;
}

sub end {
#@params (self)
#@return (int) line number for end of method
  my $self = shift;
  return $self->{'end'};
}

sub set_end {
#@params (self) (int line number)
#@return (self)
## Set end line number
  my( $self, $end ) = @_;
  return $self->{'end'} = $end;
}

sub code {
  my $self = shift;
  my @lines = grep {$_} @{$self->file->line_slice( $self->start, $self->end )||[]};
  my $html  = q();
  my @nos;
  foreach ( @lines ) {
    if( m{\A\s*(\d+):\s(.*)\Z}mxs ) {
      push @nos, $1;
      $html .= $2;
    }
  }
  my $x  = Syntax::Highlight::Perl::Improved->new;
  my %ct = (
    'Variable_Scalar'   => 'p-sc', # '080',
    'Variable_Array'    => 'p-ar', #'f70',
    'Variable_Hash'     => 'p-hs', #'80f',
    'Variable_Typeglob' => 'p-tg', #'f03',
    'Subroutine'        => 'p-sb', #'980',
    'Quote'             => 'p-qu', #'00a;background-color:white',
    'String'            => 'p-st', #00a;background-color:white',
    'Bareword'          => 'p-bw', #f00;font-weight: bold',
    'Package'           => 'p-pa', #900',
    'Number'            => 'p-nu', #f0f',
    'Operator'          => 'p-op', #900;font-weight:bold;',
    'Symbol'            => 'p-sy', #000',
    'Keyword'           => 'p-kw', #000',
    'Builtin_Operator'  => 'p-bo', #300',
    'Builtin_Function'  => 'p-bf', #001',
    'Character'         => 'p-ch', #800',
    'Directive'         => 'p-di', #399',
    'Label'             => 'p-la', #939',
    'Line'              => 'p-li', #000',
    'Comment_Normal'    => 'p-cn', #069;background-color:#ffc',
    'Comment_POD'       => 'p-cp', #069;background-color:#ffc',
  );
  $x->define_substitution(qw(< &lt; > &gt; & &amp;));    # HTML escapes.
  # install the formats set up above
  foreach ( keys %ct ) {
    $x->set_format( $_, [qq(<span class="$ct{$_}">), '</span>'] );
  }
  $html =  $x->format_string($html);
  $html =~ s{<span[^>]*></span>}{}mxgs;
  $html = join q(), map { sprintf qq(<span class="linenumber">%5d:</span> %s\n), shift @nos, $_ }
    split m{\r?\n}mxs, $html;
  return $html;
}

sub return_type {
#@params (self)
#@return (string) return type
  my $self = shift;
  return $self->{'return_type'};
}

sub set_return_type {
#@params (self) (string type)
#@return (self)
## Set return type
  my( $self, $type ) = @_;
  return $self->{'return_type'} = $type;
}

sub return_desc {
#@params (self)
#@return (string) return description
  my $self = shift;
  return $self->{'return_desc'};
}

sub set_return_desc {
#@params (self) (string description)
#@return (self)
## Set return description
  my( $self, $desc ) = @_;
  return $self->{'return_desc'} = $desc;
}

sub format_return_short {
  my $self = shift;
  return $self->{'return_type'}||q(?);
}

sub format_return {
  my $self = shift;
  if( $self->{'return_type'}||q() ) {
    return '<strong>self</strong>' if $self->{'return_type'} eq 'self';
    return sprintf '%s (%s)', $self->{'return_type'}, encode_entities($self->{'return_desc'}||q(-));
  }
  return encode_entities( $self->{'return_desc'}||q(-) );
}

sub push_parameter {
#@params (self) (string object type) (string optional state ?*+)? (string description)?
#@return (self)
  my( $self, $type, $optional, $name, $description ) = @_;
  $type        =~ s{\A\s*(.*?)\s*\Z}{$1}mxs if $type;
  $optional    =~ s{\A\s*(.*?)\s*\Z}{$1}mxs if $optional;
  $name        =~ s{\A\s*(.*?)\s*\Z}{$1}mxs if $name;
  $description =~ s{\A\s*(.*?)\s*\Z}{$1}mxs if $description;
  push @{$self->{'parameters'}}, {
    'type'        => $type        || q(),
    'optional'    => $optional    || q(),
    'name'        => $name        || q(),
    'description' => $description || q(),
  };
  return $self;
}

sub number_parameters {
  my $self = shift;
  return scalar @{$self->{'parameters'}};
}

sub format_parameters_short {
  my $self = shift;
  my $markup = join q(; ),
    map { $_->[0] ? sprintf '<span title="%s">%s</span>', $_->[0], $_->[1] : $_->[1] }
    map { [$_->{'type'}, $_->{'name'}.($_->{'optional'}||q())] }
    grep { $_->{'type'} ne 'self' && $_->{'type'} ne 'class' }
    @{$self->{'parameters'}};
  return $markup || q(-);
}

sub format_parameters {
  my $self = shift;
  return q(<p>- no parameters -</p>) unless @{$self->{'parameters'}};

  my $return = Pagesmith::HTML::TwoCol->new({'class'=>'twothird'});
  foreach (@{$self->{'parameters'}}) {
    next if $_->{'type'} eq 'self' || $_->{'type'} eq 'class';
    $return->add_entry( $_->{'type'},
      ($_->{'name'}||q()).
      (exists $OPT_MAP->{$_->{'optional'}} ? $OPT_MAP->{$_->{'optional'}} : q()),
    );
  }
  return $return->render;
}

sub push_description {
#@params (self)
#@return (string) description line
  my( $self, $line ) = @_;
  push @{$self->{'description'}}, $line;
  return $self;
}

sub format_description {
#@params (self)
#@return (string)
## Return marked up paragraph for description
  my $self = shift;
  return q() unless @{$self->{'description'}};
  return $self->markdown_html( $self->{'description'} );
}

sub push_notes {
#@params (self)
#@return (string) notes line
  my( $self, $line ) = @_;
  push @{$self->{'notes'}}, $line;
  return $self;
}

sub format_notes {
#@params (self)
#@return (string)
## Return marked up div for notes!
  my $self = shift;
  return q() unless @{$self->{'notes'}};
  return $self->markdown_html( $self->{'notes'} );
}

1;
