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
  my $config = $self->fetch_config( 1, $flush );
  my @s = values %{$config};

  my @backends       = uniq sort map { $_->{'backend_key'}  } @s;
  my @users          = uniq sort map { $_->{'maintainer'}   } @s;
  my $n_docs         =                                        @s;
  my $n_dsn_docs     =          grep { $_->{'dsn_doc' }     } @s;
  my $n_sources_docs =          grep { $_->{'sources_doc'}  } @s;

  ## no critic (LongChainsOfMethodCalls)
  return $self->html->wrap( 'DAS '.($flush ? 'Flush' : 'Summary'),
    sprintf '<div class="col1">%s</div><div class="col2">%s</div><div class="clear">%s</div>',
    $self->twocol( {'class' => 'evenwidth outer'} )
      ->add_entry( 'Sources',                  $n_docs )
      ->add_entry( 'Sources with /sources',    $n_sources_docs )
      ->add_entry( 'Sources with /DSN',        $n_dsn_docs )
      ->render,
    $self->twocol( {'class' => 'evenwidth outer'} )
      ->add_entry( 'Sources without /sources', sprintf '<strong>%d</strong>', $n_docs - $n_sources_docs )
      ->add_entry( 'Sources without /DSN',     sprintf '<strong>%d</strong>', $n_docs - $n_dsn_docs )
      ->render,
    $self->table
      ->make_sortable
      ->add_class( 'before' )
      ->set_pagination( [qw(10 25 50 all)], '25' )
      ->set_export( [qw(csv xls)] )
      ->set_colfilter
      ->add_columns(
      { 'key' => 'source',      'label' => 'Source', 'link' => $self->base_url.'/das/[[h:source]]' },
      { 'key' => 'backend',     'label' => 'Group',           'filter_values' => \@backends },
      { 'key' => 'host',        'label' => 'Host', },
      { 'key' => 'sources',     'label' => 'Sources command', 'filter_values' => [ qw(- Yes) ], 'align' => 'c' },
      { 'key' => 'dsn',         'label' => 'DSN command',     'filter_values' => [ qw(- Yes) ], 'align' => 'c' },
      { 'key' => 'maintainer',  'label' => 'Maintainer',      'default' => q(-), 'align' => 'c', 'filter_values' => \@users },
      { 'key' => 'realms',      'label' => 'Security realms', 'default' => q(-), 'align' => 'c' },
    )->add_data(
      map {  { 'source'     => $_,
               'backend'    => $config->{$_}{'backend_key'},
               'host'       => ( join q(, ), @{$config->{$_}{'backend'}} ),
               'sources'    => $config->{$_}{'sources_doc'} ? 'Yes' : q(-) ,
               'dsn'        => $config->{$_}{'dsn_doc'}     ? 'Yes' : q(-) ,
               'maintainer' => $config->{$_}{'maintainer'},
               'realms'     => join q(; ), @{$config->{$_}{'realms'}},
             } } sort keys %{$config},
    )->render,
  )->ok;
  ## use critic
}

1;