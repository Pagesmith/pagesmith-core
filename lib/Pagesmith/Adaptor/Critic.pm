package Pagesmith::Adaptor::Critic;

## Adaptor to retrieve references from pubmed or the database
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
# no warnings qw(uninitialized)

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Adaptor);

use DBI;
use Encode::Unicode;
use HTML::Entities qw(encode_entities decode_entities);
use LWP::Simple qw($ua get);
use utf8;

use Pagesmith::Object::Reference;

sub _connection_pars {
  return ( 'dbi:mysql:critic:web-vm-db-dev:3302', 'critic_rw', 'Cr171Qz' );
}

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new();
  bless $self, $class;
  return $self;
}

1;
