package Pagesmith::ImplicitIncludedModules;

## Not really used - but useful for the boot-strapper to pickup modules
## which we don't necessarily use and won't be automagically installed
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

use version qw(qv); our $VERSION = qv('0.1.0');

use DBD::Oracle;
use DBD::mysql;
use Linux::Pid;
use Perl::Tidy;
use Perl::Critic::Bangs;
use Perl::Critic::Itch;
use Perl::Critic::PetPeeves::JTRAMMELL;
use Perl::Critic::Pulp;
use Perl::Critic::Swift;
use Perl::Critic::StricterSubs;
use Perl::Critic::Storable;
use PPI;


1;
