package Pagesmith::Action::Das::Summary;

## Monitorus proxy!
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-13
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action::Das);
use List::MoreUtils qw(uniq);

sub run {
  my $self = shift;
  return $self->run_details(0);
}

sub run_details {
  my( $self, $flush ) = @_;
  my $config = $self->fetch_config( $flush );
  my @sources = uniq sort map { $_->{'backend'} } values %{$config};

  ## no critic (LongChainsOfMethodCalls)
  return $self->html->wrap( 'DAS '.($flush?'Flush':'Summary'),
    $self->table
      ->make_sortable
      ->add_class( 'before' )
      ->set_pagination( [qw(10 25 50 all)], '25' )
      ->set_export( [qw(csv xls)] )
      ->set_colfilter
      ->add_columns(
      { 'key' => 'source',  'label' => 'Source' },
      { 'key' => 'host',    'label' => 'Host',            'filter_values' => \@sources },
      { 'key' => 'sources', 'label' => 'Sources command', 'filter_values' => [ qw(- Yes) ], 'align' => 'c' },
      { 'key' => 'dsn',     'label' => 'DSN command',     'filter_values' => [ qw(- Yes) ], 'align' => 'c' },
      { 'key' => 'realms',  'label' => 'Security realms', 'default' => q(-), 'align' => 'c' },
    )->add_data(
      map {  { 'source'   => $_,
               'host'     => $config->{$_}{'backend'},
               'sources'  => $config->{$_}{'sources_doc'} ? 'Yes' : q(-) ,
               'dsn'      => $config->{$_}{'dsn_doc'}     ? 'Yes' : q(-) ,
               'realms'   => join q(; ), @{$config->{$_}{'realms'}},
             } } sort keys %{$config},
    )->render,
  )->ok;
  ## use critic
}

1;
