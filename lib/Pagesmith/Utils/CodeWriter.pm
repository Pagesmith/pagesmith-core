package Pagesmith::Utils::CodeWriter;

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

use base qw(Pagesmith::Root);
use Pagesmith::Core qw(user_info);

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);

use Date::Format qw(time2str);
use File::Basename qw(dirname);
use File::Path qw(make_path);

my %formats = qw(
  PosInt    d
  Int       d
  Float     f
  Date      date
  DateTime  dt
  NonNegInt d
);

sub new {
  my( $class, $factory ) = @_;
  my $self = {
    'conf'      => $factory->{'conf'},
    'root'      => $factory->root,
    'force'     => $factory->{'force'},
    'defn_map'  => $factory->{'defn_map'},
  };
  bless $self, $class;
  return $self;
}

sub root {
  my $self = shift;
  return $self->{'root'};
}

sub fp {
  my ($self,$string) = @_;
  $string =~ s{::}{/}mxsg;
  return $string;
}

sub comp {
  my ($self,$string) = @_;
  $string =~ s{::}{_}mxsg;
  return $string;
}

sub ky {
  my ($self,$string) = @_;
  $string =~ s{([[:lower:]\d])([[:upper:]])}{$1_$2}mxsg;
  return lc $self->comp( $string );
}

sub id {
  my ($self,$string) = @_;
  return $self->ky($string).'_id';
}

sub hr {
  my ($self,$string) = @_;
  $string =~ s{([[:lower:]\d])([[:upper:]])}{$1 $2}mxsg;
  $string =~ s{_}{ }mxsg;
  return ucfirst lc $self->comp( $string );
}

sub boilerplate {
  my $self = shift;
  return $self->{'conf'}{'boilerplate'} if exists $self->{'conf'}{'boilerplate'};

  my $details = user_info();
  my $today   = time2str( '%a, %d %b %Y', time, 'GMT' );

  $self->{'conf'}{'username'}    = $details->{'username'};
  $self->{'conf'}{'realname'}    = $details->{'name'};
  $self->{'conf'}{'today'}       = $today;
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  $self->{'conf'}{'boilerplate'} = sprintf q(
## Author         : %1$s <%2$s>
## Maintainer     : %1$s <%2$s>
## Created        : %3$s
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');
), $details->{'name'}, $details->{'username'}, $today;
#@endraw
## use critic
  return $self->{'conf'}{'boilerplate'};
}

sub root_path {
  my $self = shift;
  return $self->{'conf'}{'root_path'};
}

sub base_path {
  my $self = shift;
  return $self->{'conf'}{'base_path'};
}

sub namespace {
  my $self = shift;
  return $self->{'conf'}{'namespace'};
}

sub ns_path {
  my $self = shift;
  return $self->{'conf'}{'ns_path'};
}

sub ns_key {
  my $self = shift;
  return $self->{'conf'}{'ns_key'};
}

sub addslash {
  my( $self, $str ) = @_;
  $str =~ s{'}{\\'}mxsg;
  return $str;
}

sub ns_comp {
  my $self = shift;
  return $self->{'conf'}{'ns_comp'};
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
      return if     $_ >= @{$h};
      $h = $h->[$_];
    } else {
      return;
    }
  }
  return $h;
}

sub write_file {
  my( $self, $filename, $new_contents ) = @_;
  ## Check to see if file already exists and contents haven't changed!
  my $action = 'created';
  if( -e $filename ) {
    unless( $self->{'force'} ) {
      local $INPUT_RECORD_SEPARATOR = undef;
      if( open my $ifh, q(<), $filename ) {
        my $contents = <$ifh>;
        close $ifh; ## no critic (RequireChecked)
        return "skipped $filename" if $contents eq $new_contents;
      }
    }
    $action = 'updated';
  }
  my $fh = $self->open_file( $filename );
  return unless $fh;
  print {$fh} $new_contents; ## no critic (RequireChecked)
  close $fh;                 ## no critic (RequireChecked)
  return "$action $filename";

}

sub open_file {
  my ( $self, $file ) = @_;
  my $dir = dirname $file;
  make_path( $dir, { 'mode' => 0755 } ); ## no critic (LeadingZeros)
  open my $fh, q(>), $file;              ## no critic (RequireChecked)
  return $fh;
}

sub defn_map {
  my( $self, $key ) = @_;
  return $self->{'defn_map'}{ $key }||{('sql'=>'text')};
}

sub admin_table {
  my( $self, $type ) = @_;
  my $conf = $self->conf('objects',$type);
## no critic (InterpolationOfMetachars ImplicitNewlines)
  my $column_defs = join qq(\n),
    map { sprintf q(      { 'key' => '%s', 'label' => '%s', 'format' => '%s' },),
          $_->{'colname'}||$_->{'code'},
          $_->{'caption'}||$self->hr( $_->{'colname'}||$_->{'code'}),
          exists $formats{ $_->{'type'} } ? $formats{ $_->{'type'} } : 'h',
    }
    grep { !exists $_->{'table'} || $_->{'table'} }
    @{$conf->{'properties'}||[]};

  return sprintf q(
  my $table = $self->my_table
    ->add_columns(
%1$s
      { 'key' => 'action', 'label' => 'Edit?', 'template' => 'Edit', 'link' => '/form/%2$s_Admin_%3$s?uid=[[h:uid]]' },
    )
    ->add_data( @{$self->adaptor( '%4$s' )->fetch_%5$ss||[]} );
), $column_defs, $self->ns_comp, $self->comp( $type ), $type, $self->ky( $type );
## use critic
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

1;
