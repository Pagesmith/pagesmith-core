package Pagesmith::Utils::CodeWriter::Factory;

## Package to write packages etc!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Mon, 11 Feb 2013
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR $EVAL_ERROR);
use YAML::Loader;

use Pagesmith::Utils::CodeWriter::Action;
use Pagesmith::Utils::CodeWriter::Adaptor;
use Pagesmith::Utils::CodeWriter::Component;
use Pagesmith::Utils::CodeWriter::Form;
use Pagesmith::Utils::CodeWriter::Object;
use Pagesmith::Utils::CodeWriter::Relationship;
use Pagesmith::Utils::CodeWriter::Schema;
use Pagesmith::Utils::CodeWriter::Support;

my $defn_map = {
  'PosInt'    => { 'sql' => 'int unsigned', },
  'NonNegInt' => { 'sql' => 'int unsigned', },
  'Int'       => { 'sql' => 'int',          },
  'Float'     => { 'sql' => 'double',       },
  'Date'      => { 'sql' => 'date',         },
  'DateTime'  => { 'sql' => 'datetime',     },
  'String'    => { 'sql' => 'text',         },
};

sub new {
#@params (self) (string root) path to root of filesystem to write files.
#@return (self)
  my( $class, $root, $force ) = @_;
  my $self = {
    'conf'     => {},
    'root'     => $root,
    'child'    => {},
    'force'    => $force || 0,
    'defn_map' => $defn_map,
  };
  bless $self, $class;
  return $self;
}

sub root {
#@param (self)
#@return (string) path to root of filesystem to write files.
  my $self = shift;
  return $self->{'root'} || '/tmp';
}

sub load_config {
#@param (self)
#@return (hashref)? references to configuration structure
## returns nothing if the conf is missing OR there is an error parsing the YAML
  my( $self, $file ) = @_;
  $self->{'conf'} = {};

  return unless -e $file;

  if( open my $fh, q(<), $file ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $yl = YAML::Loader->new;
    $self->{'conf'} = eval { $yl->load( <$fh> ); };
    close $fh; ## no critic (RequireChecked)
  }

  unless ( keys %{$self->{'conf'}||{}} ) {
    warn "No valid configuration $EVAL_ERROR\n";
    return;
  }

  my $base_path = exists $self->{'conf'}{'website'}
              ? '/sites/'.$self->{'conf'}{'website'}
              : q()
              ;
  $self->{'conf'}{'root_path'} = $self->root.$base_path;
  $self->{'conf'}{'base_path'} = $self->root.$base_path.'/lib/Pagesmith';
  if( $self->{'conf'}{'namespace'} ) {
    ( $self->{'conf'}{'ns_path'}   = "/$self->{'conf'}->{'namespace'}" ) =~ s{::}{/}mxsg;
    ( $self->{'conf'}{'ns_comp'}   = $self->{'conf'}->{'namespace'}    ) =~ s{::}{_}mxsg;
    $self->{'conf'}{'ns_key'}      = lc $self->{'conf'}->{'ns_comp'};
  }
  foreach my $type ($self->objecttypes) {
    my ($uid_property) = grep { $_->{'unique'} && $_->{'unique'} eq 'uid' } @{$self->conf('objects',$type,'properties')||[]};
    $self->{'conf'}{'objects'}{$type}{'uid_property'} = $uid_property || { ('code' => 'id', 'type' => 'PosInt', 'colname' => $self->id( $type )) };
  }
  return $self->{'conf'};
}

sub action {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Action) code creator module
  my $self = shift;
  return $self->{'child'}{'action'}       ||= Pagesmith::Utils::CodeWriter::Action->new( $self );
}

sub schema {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Schema) code creator module
  my $self = shift;
  return $self->{'child'}{'schema'}       ||= Pagesmith::Utils::CodeWriter::Schema->new( $self );
}

sub component {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Component) code creator module
  my $self = shift;
  return $self->{'child'}{'component'}    ||= Pagesmith::Utils::CodeWriter::Component->new( $self );
}

sub form {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Form) code creator module
  my $self = shift;
  return $self->{'child'}{'form'}         ||= Pagesmith::Utils::CodeWriter::Form->new( $self );
}

sub support {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Support) code creator module
  my $self = shift;
  return $self->{'child'}{'support'}      ||= Pagesmith::Utils::CodeWriter::Support->new( $self );
}

sub object {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Object) code creator module
  my $self = shift;
  return $self->{'child'}{'object'}       ||= Pagesmith::Utils::CodeWriter::Object->new( $self );
}

sub adaptor {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Adaptor) code creator module
  my $self = shift;
  return $self->{'child'}{'adaptor'}      ||= Pagesmith::Utils::CodeWriter::Adaptor->new( $self );
}

sub relationship {
#@param (self)
#@return (Pagesmith::Utils::CodeWriter::Relationship) code creator module
  my $self = shift;
  return $self->{'child'}{'relationship'} ||= Pagesmith::Utils::CodeWriter::Relationship->new( $self );
}

sub objecttypes {
  my $self = shift;
  my @types = sort keys %{$self->{'conf'}{'objects'}||{}};
  return @types;
}

sub relationships {
  my $self = shift;
  my @rels = sort keys %{$self->{'conf'}{'relationships'}||{}};
  return @rels;
}

sub conf {
  my( $self, @keys ) = @_;
  my $h = $self->{'conf'};
  foreach ( @keys ) {
    if( 'HASH' eq ref $h ) {
      return unless exists $h->{$_};
      $h = $h->{$_};
    } elsif( 'ARRAY' eq ref $h ) {
      return unless $_ =~ m{\A-?\d+\Z}mxs;
      return if     $_ > @{$h} || $_ <= -@{$h};
      $h = $h->[$_];
    } else {
      return;
    }
  }
  return $h;
}

## Reporting code...
sub msg {
  my ($self,@entries) = @_;
  print "@entries\n"; ## no critic (RequireChecked);
  return $self;
}

sub created_msg {
  my( $self, $fileflag ) = @_;
  return $self->msg( "    * $fileflag" );
}

sub header {
  my( $self, $caption ) = @_;
  my $level = $caption =~ s{\A(-*)}{}mxsg ? length $1 : 0;
  return $self->blank->msg( $caption )->msg( q(=) x length $caption ) unless $level;
  return $self->blank->msg( $caption )->msg( q(-) x length $caption ) if $level == 1;
  return $self->blank->msg( "* $caption" );
}

sub blank {
  my $self = shift;
  print "\n"; ## no critic (RequireChecked);
  return $self;
}
1;
