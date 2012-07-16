package Pagesmith::SessionData;

## Store session data (move to Object)
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

use Readonly qw(Readonly);
Readonly my $CHK_LENGTH => 4;

use Digest::MD5 qw(md5_hex);

use Pagesmith::Cache;

my %appkeys;

sub check_key {
  my ( $self, $key ) = @_;
  my ( $realkey, $chk ) = split m{-}mxs, $key;
  $appkeys{$key} = substr( md5_hex($realkey), 0, $CHK_LENGTH ) eq $chk
    ? $key
    : undef;
  return $appkeys{$key};
}

sub new {

#@param (self)
#@param (Pagesmith::Page) page object (handles sessioning)
#@param (string) $appkey Application key - encoded key to "protect" application data

  my $class = shift;
  my $self  = {
    'page'    => shift,
    'ch'      => undef,
    'data'    => {},
    'changes' => [],
    'appkey'  => undef,
  };
  bless $self, $class;
  my $appkey = shift;
  $appkey = exists $appkeys{$appkey} ? $appkeys{$appkey} : $self->check_key($appkey);

  return unless $appkey;
  $self->{'appkey'} = $appkey;
  return $self;
}

sub _fetch {
  my $self = shift;
  return if $self->{'data'};

  if ( $self->page->session_id ) {    ## We have a session!
    $self->{'ch'} ||= Pagesmith::Cache->new( 'session', $self->{'id'} . q(|) . $self->{'session_id'} );
    $self->{'data'} = $self->{'ch'}->get() || {};
  } else {
    $self->{'data'} = {};
  }
  return;
}

sub put {
  my($self,@pars) = @_;

  CORE::push @{ $self->{'changes'} }, ['put', @pars];
  my $key = shift;
  if ( ref($key) eq 'ARRAY' ) {
    return unless @{$key};
    my $t    = $self->{'data'};
    my @keys = @{$key};
    my $last_entry = pop @keys;
    foreach (@keys) {
      $self->{'data'}{$_} = {} unless exists $self->{'data'};
      $t = $self->{'data'}{$_};
    }
    $t->{$last_entry} = shift;
  } else {
    $self->_fetch;
    $self->{'data'}->{$key} = $value;
  }
  return;
}

sub push { ##no critic (BuiltinHomonyms)
  my ($self,$key,@pars) = @_;
  return unless @pars;

  CORE::push @{ $self->{'changes'} }, ['push', $key, @pars];

  if ( ref($key) eq 'ARRAY' ) {
    return unless @{$key};
    my $t    = $self->{'data'};
    my @keys = @{$key};
    my $last_entry = pop @keys;
    foreach (@keys) {
      $self->{'data'}{$_} = {} unless exists $self->{'data'};
      $t = $self->{'data'}{$_};
    }
    $t->{$last_entry} ||= [];
    CORE::push @{ $t->{$last_entry} }, @pars;
  } else {
    $self->{'data'}->{$key} ||= [];
    CORE::push @{ $self->{'data'}->{$key} }, @pars;
  }
  return;
}

sub get {
  my $self = shift;
  return unless $self->key;
  return;
}

sub _store {
  my $self = shift;
  return unless @{ $self->{'changes'} };
  $self->get_session;
  my $ch = Pagesmith::Cache->new( 'session', $self->{'id'} . q(|) . $self->session_id );
  my %tmp_data = %{ $self->{'data'} };
  $self->{'data'} = undef;
  $self->_fetch;
  foreach ( @{ $self->{'changes'} } ) {
    my $action = shift @{$_};
    $self->$action(@{$_});
  }
  $ch->set( $self->{'data'} );
  return;

}

1;
