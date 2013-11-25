#!/usr//bin/perl

## Short script - produces SQL to create a new database on the server!
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

die "Usage: perl create-db.pl {database_name} (live|dev)\n\n" unless @ARGV;

## no critic (ImplicitNewlines InterpolationOfMetachars)
printf q(
create database %1$s_%2$s;
grant select,update,delete,create temporary tables,insert,lock tables,trigger on %1$s_%2$s.* to '%1$s_rw'@'%%' identified by '%1$s_rw';
grant select on %1$s_%2$s.* to '%1$s_ro'@'%%' identified by '%1$s_ro';
grant select,update,delete,create temporary tables,insert,alter,drop,create view,show view,create,index,lock tables,trigger on %1$s_%2$s.* to '%1$s_admin'@'%%' identified by '%1$s_admin';
), @ARGV;

## use critic
