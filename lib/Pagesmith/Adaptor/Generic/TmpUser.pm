package Pagesmith::Adaptor::Generic::TmpUser;

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

sub new {
  my( $class, $db_info, $r ) = @_;
  my $self = $class->SUPER::new( $db_info, $r );
  bless $self, $class;

  $self
    ->set_type( 'TmpUser' )
    ->set_code( 'code' )
    ->set_sort_order( 'username', 'state', 'password' );
  return $self;
}

1;
