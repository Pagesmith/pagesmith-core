package Pagesmith::CriticSupport;

## Base class for other web-adaptors...
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

## Supplies wrapper functions for DBI

use strict;
use warnings;
use utf8;
use Time::HiRes qw(time);
use Date::Format qw(time2str);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use Getopt::Long qw(GetOptions);


use version qw(qv); our $VERSION = qv('0.1.0');

sub new {
  my( $class, $pars ) = @_;
  my $self  = {
    'root'       => $pars->{'root'},
    'start_time' => time,
    'files'      => {},
    'html_files' => [],
    'site'       => q(),
    'paths'      => [],
    'extn'       => $pars->{'extn'},
    'report_dir' => $pars->{'dir'},
    'html_path'  => q(),
    'current_files' => {},
    'exclude'    => {},
  };
  bless $self, $class;
  return $self;
}

sub time_taken {
  my $self = shift;
  return time - $self->{'start_time'};
}

sub run_at {
  my $self = shift;
  return time2str( '%a, %d %b %Y %H:%M %Z', $self->{'start_time'} );

}
sub find_current {
  my($self) =  @_;
  my $dh;
  return unless opendir $dh, join q(/), $self->{'html_path'}, $self->{'report_dir'};
  while ( defined (my $file = readdir $dh) ) {
    $self->{'current_files'}{ $file }++ unless $file eq q(..) || $file eq q(.) || $file eq q(index.html);
  }
  closedir $dh;
  return;
}

sub remove_old {
  my($self) =  @_;
  foreach (sort keys %{$self->{'current_files'}} ) {
    unlink join q(/), $self->{'html_path'}, $self->{'report_dir'}, $_;
  }
  return;
}

sub init {
  my($self) =  @_;
  my $root;
  my $site;
  my $html_path;
  my @other;

  GetOptions(
    'root=s'  => \$root,
    'site=s'  => \$site,
    'out=s'   => \$html_path,
    'other=s' => \@other,
  );

  $self->{'root'}       = $root || $self->{'root'};
  $self->{'site'}       = $site;
  $self->{'html_path'}  = $html_path || "$self->{'root'}/$self->{'site'}/htdocs/developer/critic";
  $self->{'cache_path'} = "$self->{'root'}/critic-$self->{'report_dir'}-$self->{'site'}.packed";

  $self->{'paths'}      = { $self->{'site'} => "$self->{'root'}/$self->{'site'}/htdocs" };

  if( !@other &&  opendir my $dh, $self->{'root'}) {
    @other = grep { !$self->{'exclude'}{$_} && $_ ne $self->{'site'} && $_ ne q(.) && $_ ne q(..) } readdir $dh;
    closedir $dh;
  }
  foreach my $s ( @other ) {
    $self->{'paths'}{ $s } = "$self->{'root'}/$s/htdocs" if -d "$self->{'root'}/$s" && -d "$self->{'root'}/$s/htdocs";
  }

  if( -e $self->{'cache_path'} ) {
    if( open my $fh, '<', $self->{'cache_path'} ) {
      local $INPUT_RECORD_SEPARATOR = undef;
      my $t = eval <$fh>; ## no critic (StringyEval)
      close $fh; ## no critic (RequireChecked)
    }
  }
  return;
}

sub get {
  my $self = shift;
  foreach my $s ( keys %{$self->{'paths'}} ) {
    $self->get_files( $self->{'paths'}{$s}, $s, q(/) );
  }
  return;
}

sub get_files {
  my( $self, $path, $s, $prefix ) = @_;
  return unless -e $path && -d $path && -r $path;
  my $dh;
  return unless opendir $dh, $path;
  while ( defined (my $file = readdir $dh) ) {
    next if $file =~ m{^[.]}mxs;
    my $new_path = "$path/$file";
    if( -e $new_path && -f $new_path ) { ## no critic (Filetest_f)
      my $regexp         = qq(\\.$self->{'extn'}\\Z);
      next unless $new_path =~ m{$regexp}mxs;
      next if     $new_path =~ m{[.-](gcc|min)[.]js\Z}mxs;
      $self->{'files'}{ $s } { "$prefix$file" } = $new_path;
    } elsif( -d $new_path ) {
      $self->get_files( $new_path, $s, "$prefix$file/" );
    }
  }
  return;
}

1;
