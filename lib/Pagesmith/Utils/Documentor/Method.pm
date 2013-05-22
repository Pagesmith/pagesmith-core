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
use Pagesmith::Utils::PerlHighlighter;

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
    'returns'     => [],
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

sub _trim {
#@params (self) (string str)
#@return (string)
## Returns string with trailing and leading white space removed
  my( $self, $str ) = @_;
  return q() unless $str;
  return scalar reverse unpack 'A*',reverse unpack 'A*',$str; # Perl goo! Don't ask but it does what is says on the tin!
}

## * Push method attributes parameters/return onto object

sub push_return {
#@params (self) (string object type) (string optional state - ?*+)? (string description)?
#@return (self)
## Pushes a new "return" object onto the method
  my( $self, $type, $optional, $description ) = @_;
  push @{$self->{'returns'}}, {
    'type'        => $self->_trim($type),
    'optional'    => $self->_trim($optional),
    'description' => $self->_trim($description),
  };
  return $self;
}

sub push_parameter {
#@params (self) (string object type) (string name)? (string optional state - either ?*+)? (string description)?
#@return (self)
## Pushes a new "parameter" onto the method
  my( $self, $type, $name, $optional, $description ) = @_;
  push @{$self->{'parameters'}}, {
    'type'        => $self->_trim($type),
    'optional'    => $self->_trim($optional),
    'name'        => $self->_trim($name),
    'description' => $self->_trim($description),
  };
  return $self;
}

sub push_description {
#@params (self) (string line)
#@return (self)
## Pushes line of description
  my( $self, $line ) = @_;
  push @{$self->{'description'}}, $line;
  return $self;
}

sub push_notes {
#@params (self) (string line)
#@return (self)
## Pushes line of notes section
  my( $self, $line ) = @_;
  push @{$self->{'notes'}}, $line;
  return $self;
}

## * Getting and formatting parameters/return...

sub number_parameters {
#@params (self)
#@return (int) Number of parameters for method
  my $self = shift;
  return scalar @{$self->{'parameters'}};
}

sub format_return_short {
#@params (self)
#@return (html)
## Produces a "1-liner" list of return values to be squirted into a table cell
  my $self = shift;
  return q(?) unless @{$self->{'returns'}};
  return join q(, ), map { "$_->{'type'}$_->{'optional'}" } @{ $self->{'returns'}};
}

sub format_return {
#@params (self)
#@return (html)
## Renders returns of method in a two col format
  my $self = shift;
  return q(-) unless @{$self->{'returns'}};

  my $return = Pagesmith::HTML::TwoCol->new({'class'=>'twothird','hide_duplicate_keys'=>0});
  foreach (@{$self->{'returns'}}) {
    $return->add_entry( $_->{'type'},
      ($_->{'description'}||q()).
      (exists $OPT_MAP->{$_->{'optional'}} ? $OPT_MAP->{$_->{'optional'}} : q()),
    );
  }
  return $return->render;
}

sub format_parameters_short {
#@params (self)
#@return (html)
## Produces a "1-liner" list of parameters to be squirted into a table cell
  my $self = shift;
  my $markup = join q(; ),
    map { $_->[0] ? sprintf '<span title="%s">%s</span>', $_->[0], $_->[1] : $_->[1] }
    map { [$_->{'type'}, $_->{'name'}.($_->{'optional'}||q())] }
    grep { $_->{'type'} ne 'self' && $_->{'type'} ne 'class' }
    @{$self->{'parameters'}};
  return $markup || q(-);
}

sub format_parameters {
#@params (self)
#@return (html)
## Renders parameters of method in a two col format
  my $self = shift;
  return q(<p>- no parameters -</p>) unless @{$self->{'parameters'}};

  my $return = Pagesmith::HTML::TwoCol->new({'class'=>'twothird','hide_duplicate_keys'=>0});

  foreach (@{$self->{'parameters'}}) {
    next if $_->{'type'} eq 'self' || $_->{'type'} eq 'class';
    $return->add_entry(
      ("$_->{'name'}"||$_->{'type'}||q(-)).
      (exists $OPT_MAP->{$_->{'optional'}} ? $OPT_MAP->{$_->{'optional'}} : q()),
      $_->{'type'}||q(-),
    );
    $return->add_entry( q(&nbsp;), $_->{'description'} ) if $_->{'description'};
  }
  return $return->render;
}

sub format_description {
#@params (self)
#@return (html)
## Return marked up paragraph for description
  my $self = shift;
  return q() unless @{$self->{'description'}};
  return $self->markdown_html( $self->{'description'} );
}


sub format_notes {
#@params (self)
#@return (html)
## Return marked up div for notes!
  my $self = shift;
  return q() unless @{$self->{'notes'}};
  return $self->markdown_html( $self->{'notes'} );
}

sub code {
#@params (self)
#@return (html)
## Return syntax highlighted copy of code for method (without documenation lines)
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
  $html = Pagesmith::Utils::PerlHighlighter->new->format_string($html);
  $html =~ s{<span[^>]*></span>}{}mxgs;
  $html = join q(), map { sprintf qq(<span class="linenumber">%5d:</span> %s\n), shift @nos, $_ }
    split m{\r?\n}mxs, $html;
  return $html;
}


1;
