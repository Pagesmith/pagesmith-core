package Pagesmith::Utils::CodeWriter::Adaptor;

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
  my $filename = sprintf '%s/Adaptor%s.pm',$self->base_path,$self->ns_path;

## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::Adaptor::%1$s;

## Base adaptor for objects in %1$s namespace
%2$s
use base qw(Pagesmith::Adaptor);

sub connection_pars {
#@params (self)
#@return (string)
## Returns key to database connection in configuration file

  my $self = shift;
  return q(%3$s);
}

sub get_other_adaptor {
#@params (self) (string object type)
#@return (Pagesmith::Adaptor::%1$s)
## Returns a database adaptor for the given type of object.

  my( $self, $type ) = @_;
  ## Get the adaptor from the "pool of adaptors"
  ## If the adaptor doesn't exist then we well get it, and create
  ## attach it to the pool

  my $adaptor = $self->get_adaptor_from_pool( $type );
  return $adaptor || $self->get_adaptor(      "%1$s::$type", $self )
                          ->add_self_to_pool( $type );
}

1;

__END__

),
    $self->namespace,    ## %1$
    $self->boilerplate,  ## %2$
    $self->ns_key,       ## %3$
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

sub create {
  my ($self,$type) = @_;
  my $filename = sprintf '%s/Adaptor%s/%s.pm',$self->base_path,$self->ns_path, $self->fp( $type );

  my $type_ky      = $self->ky( $type );
  my $conf         = $self->conf('objects',$type);
  my $uid_property = $conf->{'uid_property'}{'colname'}||$conf->{'uid_property'}{'code'}||'id',   ## %4$
  my $table_name   = $type_ky;
  my @columns      = map { $_->{'colname'} || lc $_->{'code'} } @{$conf->{'properties'}||[]};
  push @columns, map { $_->{'colname'} || (lc $self->ky( $_->{'object'}).'_id') }
    grep { $_->{'count'} ne 'many' } @{$conf->{'has'}||[]};
  my $col_names = join q(, ), @columns;
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::Adaptor::%1$s::%2$s;

## Adaptor for objects of type %2$s in namespace %1$s
%3$s
use base qw(Pagesmith::Adaptor::%1$s);
use Pagesmith::Object::%1$s::%2$s;

sub make_%4$s {
#@params (self), (string{})
#@return (Pagesmith::Object::%1$s::%2$s)
## Take a hashref (usually retrieved from the results of an SQL query) and create a new
## object from it.
  my( $self, $hashref ) = @_;
  return Pagesmith::Object::%1$s::%2$s->new( $self, $hashref );
}

sub create {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)
## Create an empty object
  my $self = shift;
  return $self->make_%4$s({});
}

sub store {
#@params (self) (Pagesmith::Object::%1$s::%2$s object)
#@return (boolean)
## Store object in database
  my( $self, $my_object ) = @_;
  return 1;
}

sub update {
#@params (self) (Pagesmith::Object::%1$s::%2$s object)
#@return (boolean)
## Update object in database
  my( $self, $my_object ) = @_;
  return 1;
}

## no critic (ImplicitNewlines)
sub fetch_%4$ss {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)*
## Return all objects from database!
  my $self = shift;
  my $sql = 'select %5$s
               from %6$s
              order by %7$s';
  return [ map { $self->make_%4$s( $_ ) } @{$self->all_hash( $sql )||[]} ];
}

sub fetch_%4$s {
#@params (self)
#@return (Pagesmith::Object::%1$s::%2$s)?
## Return objects from database with given uid!
  my( $self, $uid ) = @_;
  my $sql = 'select %5$s
               from %6$s
              where %7$s = ?';
  my $%4$s = $self->hash( $sql, $uid );
  return unless $%4$s;
  return $self->make_%4$s( $%4$s );
}
## use critic

1;

__END__

),
    $self->namespace,   ## $1s
    $type,              ## $2s
    $self->boilerplate, ## $3s
    $type_ky,           ## $4s
    $col_names,         ## $5s
    $table_name,        ## $6s
    $uid_property,      ## $7s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

1;

