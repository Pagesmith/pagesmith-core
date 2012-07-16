package Pagesmith::Adaptor::Generic::Profile;

## Adaptor for comments database
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

use base qw(Pagesmith::Adaptor::Generic);

use Pagesmith::Object::Generic::Profile;
use Pagesmith::Config;

sub get_projects {
  my $self = shift;
  unless( defined $self->{'projects'} ) {
    my $t = Pagesmith::Config->new( { 'file' => 'projects', 'location' => 'site' } )
      ->load( 1 )->get;
    $self->{'projects'} = { map { ($_->{'code'} => $_) } @{$t||[]} };
  }
  return $self->{'projects'};
}

sub project {
  my( $self, $code ) = @_;
  my $p = $self->get_projects;
  return unless exists $p->{$code};
  return $p->{'code'};
}

sub create {
  my( $self, @pars ) = @_;
  return Pagesmith::Object::Generic::Profile->new( $self, @pars );
}

sub new {
  my( $class, $db_info, $r ) = @_;
  my $self = $class->SUPER::new( $db_info, $r );
  $self->{'projects'} = undef;
  bless $self, $class;

  $self
    ->set_type( 'profile' )
    ->set_code( 'username' )
    ->set_sort_order( 'project', 'surname', 'givenname' );
  return $self;
}

1;
