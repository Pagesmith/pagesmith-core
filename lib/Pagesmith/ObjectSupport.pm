package Pagesmith::ObjectSupport;

## Base class for auto-creating methods from configuration...!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Thu, 23 Jan 2014
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use Const::Fast qw(const);
const my $DEFAULT_PAGE => 25;

sub adaptor {
#@params (self) (sting object type)
#@return (Pagesmith::Adaptor::..)
## Return a database adaptor for objects of supplied type - getting from pool
## so we don't duplicate.

  my ( $self, $type ) = @_;

  unless( exists $self->{'_base_adaptor'} ) {
    $self->{'_base_adaptor'} = $self->get_adaptor( $self->base_class );
    ## Failed so we stop here!
    return unless $self->{'_base_adaptor'};
    if( $self->is_web ) {
      $self->{'_base_adaptor'}->attach_user_web(    $self->user );
    } else {
      $self->{'_base_adaptor'}->attach_user_script( $self->user );
    }
  }
  ## This is a raw adaptor so return it!
  return $self->{'_base_adaptor'} unless defined $type;

  unless( exists $self->{'_adaptors'}{$type} ) {
    $self->{'_adaptors'}{$type} = $self->{'_base_adaptor'}->get_other_adaptor( $type );
  }

  return $self->{'_adaptors'}{$type};
}

sub my_table {
#@params (self)
#@return (Pagesmith::HTML::Table)
## Default table setup for site...

  my $self = shift;
  return $self->table
    ->add_classes(qw(before))
    ->make_sortable
    ->set_colfilter
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

sub me {
  my ( $self, $create ) = @_;
  ## no critic (LongChainsOfMethodCalls)
  return $self->{'me'} ||= $self->adaptor( 'User' )->fetch_user_by_email( $self->user->email ) ||
                           ($create ? $self->adaptor('User')->create->set_email( $self->user->email )->store : undef );
  ## use critic
}


1;
