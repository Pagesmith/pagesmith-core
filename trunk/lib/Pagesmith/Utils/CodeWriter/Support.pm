package Pagesmith::Utils::CodeWriter::Support;

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

use base qw(Pagesmith::Utils::CodeWriter);

sub base_class {
  my $self = shift;
  my $filename = sprintf '%s/Support%s.pm',$self->base_path,$self->ns_path ;

## no critic (ImplicitNewlines InterpolationOfMetachars)
#@raw
  my $perl = sprintf q(package Pagesmith::Support::%1$s;

## Base class shared by actions/components in %1$s namespace
%2$s
use Const::Fast qw(const);
const my $DEFAULT_PAGE => 25;

## Support functions to generate HTML blocks
## -----------------------------------------

sub my_table {
#@params (self)
#@return (Pagesmith::HTML::Table)
## Default table setup for site...

  my $self = shift;
  return $self->table
    ->add_classes(qw(before))
    ->make_sortable
    ->set_filter
    ->set_export( [qw(txt csv xls)] )
    ->set_pagination( [qw(10 25 50 100 all)], $DEFAULT_PAGE );
}

## If you wish to use a different "table" class for admin tables you can define it here!

sub admin_table {
#@params (self)
#@return (Pagesmith::HTML::Table)
## Default "admin" table setup for site...

  my $self = shift;
  return $self->my_table;
}

## Support functions to shared by actions/components e.g. database adaptors...
## ---------------------------------------------------------------------------
##
## This is the default "adaptor" call which currently bases the adaptor purely
## on the type of object - to allow more complex rules and caching can add
## other properties to this method! e.g. site name, species, sub-name...

sub adaptor {
#@params (self) (sting object type)
#@return (Pagesmith::HTML::Table)
## Return a database adaptor for objects of supplied type - getting from pool
## so we don't duplicate.

  my ( $self, $type ) = @_;
  unless( exists $self->{'_base_adaptor'} ) {
    $self->{'_base_adaptor'} ||= $self->get_adaptor( '%1$s::'.$type );
  }

  ## This is a raw adaptor so return it!
  return $self->{'_base_adaptor'} unless defined $type;

  unless( exists $self->{'_adaptors'}{$type} ) {
    $self->{'_adaptors'}{$type} = $self->{'_base_adaptor'}->get_other_adaptor( $type );
  }
  return $self->{'_adaptors'}{$type};
}

1;

__END__

Purpose
-------

The purpose of the Pagesmith::Support::%1$s module is to
place methods which are to be shared between the following modules:

* Pagesmith::Action::%1$s
* Pagesmith::Component::%1$s

Common functionality can include:

* Default configuration for tables, two-cols etc
* Database adaptor calls
* Accessing configurations etc

),
    $self->namespace,    #expands as %1$
    $self->boilerplate,  #expands as %2$
    ;
#@endraw
## use critic

  return $self->write_file( $filename, $perl );
}

1;
