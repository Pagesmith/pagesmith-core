package Pagesmith::Utils::ServerInfo;

## Monitorus proxy!
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
use feature qw(switch);

use POSIX qw(floor);
use Readonly qw(Readonly);
use Sys::Hostname qw(hostname);

Readonly my $K => 1024;
Readonly my $DAY           => 24;
Readonly my $MIN           => 60;

my %mem_keys = qw(
  MemTotal  mem
  MemFree   free
  SwapTotal swap
  SwapFree  swpf
);

use base qw(Pagesmith::Root);
use Pagesmith::Core qw(user_info); ## Used to get users home directory to get to SSH keys...

sub new {
  my( $class, $params ) = @_;

  my $user_info     = user_info;

  my $self = {
    'host'      => $params->{'host'} || hostname,
    'me'        => $user_info->{'username'},
    'id_file'   => $user_info->{'home'}.'/.ssh/pagesmith/server-info',
    'user'      => $params->{'user'} || $user_info->{'username'},
    'user_home' => $params->{'user_home'}||q(),
    'script'    => $params->{'script'}||'server_info',
    'raw'       => {},
    'disks'     => {},
    'nfs'       => {},
    'cpus'      => 0,
    'command'   => [],
    map { ($_ => q(-)) } qw(
      success error uptime idle load_1 load_5 load_15 jobs kernel description release codename distributor
      perl php mysqld apache user_dirs software updates sec_updates packages upgrade reboot mac_addr ip_addr
      bcast_addr gway_addr ip6_addr
    ),
  };
  unless( $self->{'user_home'} ) {
    my ($name,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam $self->{'user'};
    $self->{'user_home'} = $dir;
  }
  bless $self, $class;
  return $self;
}

sub process {
  my $self = shift;
  return if $self->get_data;
  foreach my $method ( map { "process_$_" } keys %{$self->{'raw'}} ) {
    $self->$method if $self->can( $method );
  }
  $self->munge_info;
  return;
}

sub munge_info {
  my $self = shift;
  $self->{'uptime_hr'} = $self->format_duration( $self->{'uptime'} );
  $self->{'used'}      = $self->{'mem'}  - $self->{'free'};
  $self->{'swpu'}      = $self->{'swap'} - $self->{'swpf'};
  $self->{'idle_p'}    = $self->{'idle'}/$self->{'uptime'}/$self->{'cpus'} if $self->{'uptime'} && $self->{'cpus'};
  $self->{'used_p'}    = 1-$self->{'idle_p'};
  if( $self->{'description'} =~ m{(\d+\.\d+\.\d+)}mxs ) {
    $self->{'release'} = $1;
  }
  return $self;
}

sub format_duration {
  my( $self, $dur ) = @_;
  my $days  = floor $dur / $DAY / $MIN / $MIN;
  $dur -= $DAY * $MIN * $MIN * $days;
  my $hours = floor $dur / $MIN / $MIN;
  $dur -= $hours * $MIN * $MIN;
  my $mins  = floor $dur / $MIN;
  $dur -= $mins * $MIN;

  return sprintf '%d d %d h %02d:%05.2f', $days, $hours, $mins, $dur;
}

sub get_data {
  my $self = shift;

  my $command_string = $self->{'user_home'}.'/bin/'.$self->{'script'}; ## This script has to occur on all machines that are being connected to!
  my $user          = join q(@), $self->{'user'}, $self->{'host'};

  my $command_ref = exists $ENV{'SSH_AUTH_SOCK'}
    ? ['/bin/bash', '-c', sprintf q('SSH_AUTH_SOCK="" /usr/bin/ssh -i %s %s %s'), $self->{'id_file'}, $user, $command_string ]
    : ['/usr/bin/ssh', '-i', $self->{'id_file'}, $user, $command_string ]
    ;
  my $output = $self->run_cmd( $command_ref );
  $self->{'command'} = $command_ref;
  $self->{'success'} = $output->{'success'};

  unless( $output->{'success'} ) {
    $self->{'error'} = join qq(\n), @{$output->{'stderr'}};
    return 1;
  }

  my $current;
  foreach( @{$output->{'stdout'}} ) {
    if( m{\A=X=(\w+)\Z}mxs ) { ## Block separator - between shell commands...
      $current = $1;
      next;
    }
    next unless $current;
    if( $current eq 'disk' && m{\A\s+(\d.*)\Z}mxs ) {
      $self->{'raw'}{$current}[-1] .= qq( $1);
    } else {
      push @{$self->{'raw'}{$current}}, $_;
    }
  }
  return;
}

##
## Routines to process each chunk of the data!
##

sub process_meminfo {
  my $self = shift;
  foreach( @{$self->{'raw'}{'meminfo'}} ) {
    $self->{$mem_keys{$1}} = $2/$K/$K if m{\A(\S+):\s+(\d+)\skB}mxs && exists $mem_keys{$1};
  }
  return;
}

sub process_cpuinfo {
  my $self = shift;
  foreach( @{$self->{'raw'}{'cpuinfo'}} ) {
    $self->{'cpus'}++ if m{\Aprocessor\s+:}mxs;
  }
  return;
}

sub process_info {
  my $self = shift;
  ## Get information about the current load
  my $uptime_line  = shift @{$self->{'raw'}{'info'}};
  my $load_line    = shift @{$self->{'raw'}{'info'}};
  ($self->{'uptime'}, $self->{'idle'})  = split m{\s+}msx, $uptime_line;
  my $jobs;
  ($self->{'load_1'}, $self->{'load_5'}, $self->{'load_15'}, $jobs ) = split m{\s+}msx, $load_line;
  my( $running, $total ) = split m{/}mxs, $jobs;
  $self->{'jobs'} = $total;

  ## Now information about kernel version & debian/ubuntu version
  my $version_line = shift @{$self->{'raw'}{'info'}};
  if( $version_line =~ m{Linux\sversion\s(\S+)\s}mxs ) {
    $self->{'kernel'} = $1;
  }

  foreach( @{$self->{'raw'}{'info'}} ) {
    if( m{\A(.*?)(?:\s+ID)?:\s+(.+?)\s*\Z}mxs ) {
      $self->{(lc $1)} = $2;
    }
  }
  unshift @{$self->{'raw'}{'info'}}, $uptime_line, $load_line, $version_line;
  return;
}
sub process_perl {
  my $self = shift;
  $self->{'perl'} = $self->{'raw'}{'perl'}[0] if @{$self->{'raw'}{'perl'}};
  return;
}

sub process_php {
  my $self = shift;
  $self->{'php'} = $self->{'raw'}{'php'}[0] if @{$self->{'raw'}{'php'}};
  return;
}

sub process_mysql {
  my $self = shift;
  if( @{$self->{'raw'}{'mysql'}} && $self->{'raw'}{'mysql'}[0] =~ m{Ver\s(\S+)}mxs ) {
    $self->{'mysqld'} = $1;
  }
  return;
}

sub process_apache {
  my $self = shift;
  if( @{$self->{'raw'}{'apache'}} && $self->{'raw'}{'apache'}[0] =~ m{:\s+(Apache/\S+)}mxs ) {
    $self->{'apache'} = $1;
  }
  return;
}

sub process_disk {
  my $self = shift;
## Finally the disk block
  foreach( @{$self->{'raw'}{'disk'}} ) {
    next if m{\A(?:Filesystem|none|tmpfs|udev)\s}mxs;
    next if m{/boot\Z}mxs;
    ## no critic (CaptureWithoutTest)
    given( $_ ) {
      when( m{\s/nfs/users/}mxs                        ) { $self->{'user_dirs'} = 'Y'; }
      when( m{\s(/vol)?/software\b}mxs                 ) { $self->{'software'}  = 'Y'; }
      when( m{\s(/(nfs|www/mnt)/\S+)\Z}mxs             ) { $self->{'nfs'}{$1}++;       }
      when( m{\s(/(?:shared_|web_|)tmp)\Z}mxs          ) { $self->{'nfs'}{$1}++;       }
      when( m{\A\S*\s+(\d+)\s+(\d+)\s+(\d+)\s+\d+%\s+(/\S*)\Z}mxs ) {
        # $1 - size of disk in (k);
        # $2 - amount used  in (k);
        # $3 - amount free  in (k);
        # $4 - mount path of disk.
        $self->{'disks'}{ $4 } = { 'size' => $1/$K/$K, 'used' => $2/$K/$K, 'available' => $3/$K/$K };
      }
    }
    ## use critic
  }
  return;
}

sub process_apt {
  my $self = shift;
  if( @{$self->{'raw'}{'apt'}} ) {
    my $first = shift @{$self->{'raw'}{'apt'}};
    my( $n_updates, $n_security )  = split m{;}mxs, $first;
    $self->{'updates'}     = $n_updates;
    $self->{'sec_updates'} = $n_security;
    $self->{'packages'}    = join q(, ), sort @{$self->{'raw'}{'apt'}};
    unshift @{$self->{'raw'}{'apt'}}, $first;
  } else {
    $self->{'updates'}     = 0;
    $self->{'sec_updates'} = 0;
    $self->{'packages'}    = q();
  }
  return;
}

sub process_upgrade {
  my $self = shift;
  $self->{'upgrade'} = @{$self->{'raw'}{'upgrade'}} ? $self->{'raw'}{'upgrade'}[0] : q();
  if($self->{'upgrade'} =~ m{New\srelease\s'(.*?)'\savailable\.}mxsi) {
    $self->{'upgrade'} = $1;
  }
  return $self;
}

sub process_reboot {
  my $self = shift;
  if( @{$self->{'raw'}{'reboot'}} ) {
    if( $self->{'raw'}{'reboot'}[0] eq '--- No reboot required ---' ) {
      $self->{'reboot'} = 'No';
    } elsif( $self->{'raw'}{'reboot'}[0] eq q(-) ) {
      $self->{'reboot'} = q(?);
    } else {
      $self->{'reboot'} = 'Yes';
    }
  }
  return;
}

sub process_ipconfig {
  my $self = shift;
  foreach ( @{$self->{'raw'}{'ipconfig'}||[]} ) {
    ## no critic (CaptureWithoutTest)
    if( m{\A(\w+)}mxs ) {
      $self->{'interface'} = $1;
    }
    given( $_ ) {
      when( m{HWaddr\s+(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)}mxs ) {
        $self->{'mac_addr'}  = $1;
      }
      when( m{inet\s+addr:(\d+\.\d+\.\d+\.\d+)\s+Bcast:(\d+\.\d+\.\d+\.\d+)\s+Mask:(\d+\.\d+\.\d+\.\d+)}mxs ) {
        $self->{'ip_addr'}    = $1;
        $self->{'bcast_addr'} = $2;
        $self->{'gway_addr'}  = $3;
      }
      when( m{inet6\s+addr:\s*([\w:]+(/\d+)?)\s+}mxs ) {
        $self->{'ip6_addr'}   = $1;
      }
    }
    ## use critic
  }
  return;
}

1;
