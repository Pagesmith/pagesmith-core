package Pagesmith::Utils::Documentor::Package;

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

use Pagesmith::Utils::Documentor::Method;

use Const::Fast qw(const);
const my $SKIP_MODULES => { map { ($_=>1) } qw(strict utf8 warnings version Readonly Const::Fast) };

sub new {
#@params (class) (Pagesmith::Utils::Documentor::File file object)
#@return (self)
## Generate file object...
  my( $class, $file ) = @_;
  my $self = {
    'name'              => undef,
    'root_directory'    => undef,
    'doc_filename'      => undef,
    'description'       => [],
    'notes'             => [],
    'methods'           => [],
    'file'              => $file,
    'parents'           => [],
    'used_packages'     => {},
    'imported_methods'  => {},
    'constants'         => {},
    'rcs'               => { map { ($_ => undef) } ('Author','Created','Maintainer','Last commit by','Last modified','Revision','Repository URL') },
  };
  bless $self, $class;
  return $self;
}

sub set_parents {
#@params (self) (string parent module)+
#@return (self)
  my( $self, @modules ) = @_;
  $self->{'parents'} = \@modules;
  return $self;
}

sub parents {
#@params (self)
#@return (string)+ list of parent module names
  my $self = shift;
  return @{$self->{'parents'}};
}

sub push_use {
#@params (self) (string module name) (string[] method names)
#@return (self)
  my( $self, $module, @imported ) = @_;
  return if exists $SKIP_MODULES->{$module};

  $self->{'used_packages'}{$module} = \@imported;
  foreach (@imported) {
    $self->{'imported_methods'}{$_} = $module;
  }
  return $self;
}

sub used_packages {
#@params (self)
#@return (string)+ list of used packages;
  my $self = shift;
  return %{$self->{'used_packages'}};
}

sub push_constant {
#@params (self) (string name) (string value)
#@return (self)
  my( $self, $name, $value ) = @_;
  $self->{'constants'}{$name} = $value;
  return $self;
}

sub constants {
#@params (self)
#@return (string)+ list of used packages;
  my $self = shift;
  return %{$self->{'constants'}};
}

sub name {
#@params (self)
#@return (string) name
## Returns name of package;
  my $self = shift;
  return $self->{'name'};
}

sub set_name {
#@params (self) (string name)
#@return (self)
## Set name
  my( $self, $name ) = @_;
  $self->{'name'} = $name;
  return $self;
}

sub root_directory {
#@params (self)
#@return (string) name
## Returns root_directory containing package;
  my $self = shift;
  return $self->{'root_directory'};
}

sub set_root_directory {
#@params (self) (string root_directory)
#@return (self)
## Set root directory
  my( $self, $root_directory ) = @_;
  $self->{'root_directory'} = $root_directory;
  return $self;
}

sub doc_filename {
#@params (self)
#@return (string) name
## Returns doc_filename used to store documentation
  my $self = shift;
  return $self->{'doc_filename'};
}

sub set_doc_filename {
#@params (self) (string doc_filename)
#@return (self)
## Sets doc filename used to store documentation
  my( $self, $doc_filename ) = @_;
  $self->{'doc_filename'} = $doc_filename;
  return $self;
}

sub set_rcs_keyword {
#@params (self) (string key) (string value)
#@return (self)
## Set rcs keyword
  my( $self, $key, $value ) = @_;
  $self->{'rcs'}{$key} = $value =~ m{\A\$\w+:\s*(.*?)\s*\$\Z}mxs ? $1 : $value;
  return $self;
}

sub rcs_keyword {
#@params (self) (string key)
#@return (self)
## Get rcs keyword
  my( $self, $key ) = @_;
  return $self->{'rcs'}{$key}||q();
  return $self;
}

sub push_description {
#@params (self) (string line)
#@return (self)
## Push a description line...
  my( $self, $description ) = @_;
  push @{$self->{'description'}}, $description;
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
#@params (self) (string line)
#@return (self)
## Push a notes line...
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

sub new_method {
#@params (self) (string method name)
#@return (Pagesmith::Utils::Documentor::Method)
## Create a new Pagesmith::Utils::Documentor::Method object;
  my( $self, $name ) = @_;
  my $method = Pagesmith::Utils::Documentor::Method->new( $name, $self->file );
  push @{$self->{'methods'}}, $method;
  return $method;
}

sub is_action {
  my $self = shift;
  return ! index $self->name, 'Pagesmith::Action::';
}

sub is_component {
  my $self = shift;
  return ! index $self->name, 'Pagesmith::Component::';
}

sub methods {
#@params (self)
#@return (Pagesmith::Utils::Documentor::Method)+ Method objects
## Return array of methods
  my $self = shift;
  return
    grep { $self->is_action     && $_->name ne 'run' ||
           $self->is_component  && $_->name ne 'execute' &&
            $_->name ne 'usage' && $_->name ne 'define_options' ||
           ! $self->is_component && ! $self->is_action }
    @{$self->{'methods'}};
}

sub documented_methods {
#@params (self)
#@return (Pagesmith::Utils::Documentor::Method)+ Method objects
## Return array of methods that have been documented
  my $self = shift;
  return grep { $_->documented } $self->methods;
}

sub file {
#@params (self)
#@return (Pagesmith::Utils::Documentor::File)
## returns attached file object!
  my $self = shift;
  return $self->{'file'};
}

1;
