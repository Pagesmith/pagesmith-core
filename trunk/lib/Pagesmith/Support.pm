package Pagesmith::Support;

## Base class to add common functionality!
##
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

use base qw(Pagesmith::Root);

use List::MoreUtils qw(any);
use HTML::Entities qw(encode_entities);
use Apache2::Request;

use Pagesmith::Adaptor;
use Pagesmith::Session::User;

## empty constructor!

## Code that requires r!

sub dump_events {
  my $self = shift;
  $self->push_message( $self->SUPER::dump_events, 'info', 1 );
  return $self;
}

sub get_adaptor {
  my( $self, $type, @params ) = @_;
  my $module = 'Pagesmith::Adaptor::'.$type;
  return $self->dynamic_use( $module ) ? $module->new( @params, $self->r ) : undef;
}

sub get_adaptor_conn {
  my( $self, $conn, @params ) = @_;
  return Pagesmith::Adaptor->new( $conn, $self->r );
}


sub user {
  my( $self, $r ) = @_;
  unless( defined $self->{'user'} ) {
    $self->{'user'} = $r->pnotes( 'user_session' );
    unless( $self->{'user'} ) {
      $self->{'user'} = Pagesmith::Session::User->new( $r );
      if( $self->{'user'}->read_cookie ) {
        $r->pnotes( 'user_session'    => $self->{'user'} );  ## Store the uses session as a pnote!
        $r->notes->set(  'user_session_id',  $self->{'user'}->uuid );
      }
    }
    $self->{'user'}->fetch;
  }
  return $self->{'user'};
}

sub referer {
  my $self = shift;
  return $self->r->headers_in->{'Referer'}||q();
}

sub set_navigation_path {
  my( $self, $path ) = @_;
  $self->r->headers_out->set( 'X-Pagesmith-NavPath', $path );
  return $self;
}

sub r {
  my $self = shift;
  return $self->{'_r'};
}

sub set_r {
  my ($self,$r ) = @_;
  $self->{'_r'} = $r;
  return $self;
}

sub base_url {
  my( $self ) = @_;
  return unless $self->r;
  return join q(://),
    $self->r->headers_in->{'X-is-ssl'} ? 'https' : 'http',
    $self->r->headers_in->{'Host'};
}

sub get_session {
  my( $self, $type, $r, @params ) = @_;
  $r ||= $self->r;
  my $module = 'Pagesmith::Session::'.$type;
  return $self->dynamic_use( $module ) ? $module->new( $r, @params ) : undef;
}

sub set_body_id {
  my( $self, $id ) = @_;
  $self->r->pnotes('body_id', $id );
  return $self;
}

sub push_css_files {
  my( $self, @files ) = @_;
  my $css_ref = $self->r->pnotes('css_files');
  unless( $css_ref ) {
    $css_ref = {};
    $self->r->pnotes('css_files',$css_ref);
  }
  $css_ref->{'all'}||=[];
  $self->push_unless_exists( $css_ref->{'all'}, $_ ) foreach @files;
  return $self;
}

sub push_ie67_css_files {
  my( $self, @files ) = @_;
  my $css_ref = $self->r->pnotes('css_files');
  unless( $css_ref ) {
    $css_ref = {};
    $self->r->pnotes('css_files',$css_ref);
  }
  $css_ref->{'if lt IE 8'}||=[];
  $self->push_unless_exists( $css_ref->{'if lt IE 8'}, $_ ) foreach @files;
  return $self;
}

sub push_ie678_css_files {
  my( $self, @files ) = @_;
  my $css_ref = $self->r->pnotes('css_files');
  unless( $css_ref ) {
    $css_ref = {};
    $self->r->pnotes('css_files',$css_ref);
  }
  $css_ref->{'if lt IE 9'}||=[];
  $self->push_unless_exists( $css_ref->{'if lt IE 9'}, $_ ) foreach @files;
  return $self;
}

sub push_unless_exists {
  my( $self, $array_ref, $value ) = @_;
  push @{$array_ref}, $value unless any { $value eq $_ } @{$array_ref};
  return $self;
}

sub push_javascript_files {
  my( $self, @files ) = @_;
  my $js_ref = $self->r->pnotes('js_files');
  unless( $js_ref ) {
    $js_ref = [];
    $self->r->pnotes('js_files',$js_ref);
  }
  $self->push_unless_exists( $js_ref, $_ ) foreach @files;
  return $self;
}

sub embed_css_files {
  my $self = shift;
  $self->r->pnotes->{'embed_css'} = 1;
  return $self;
}

sub embed_javascript_files {
  my $self = shift;
  $self->r->pnotes->{'embed_js'} = 1;
  return;
}

sub flush_cache {
  my( $self, $flag ) = @_;
  unless( exists $self->{'flush_cache'} ) {
    if( $self->r ) {
      $self->{'flush_cache'} = $self->r->headers_in->get('X-Flush-Cache');
      $self->{'flush_cache'} = $self->apr->param('flush_cache') unless defined $self->{'flush_cache'};
    }
  }
  return $self->SUPER::flush_cache( $flag );
}

sub apr {
  my $self = shift;
  $self->{'_apr'} ||= Apache2::Request->new( $self->r );
  return $self->{'_apr'};
}

## Functions which generate a table from an SQL query - useful for testing!

sub table_from_query {
  my( $self, $dba, $sql, @params ) = @_;
  return $self->_table_from_query( $self->table, $dba, $sql, @params );
}

sub my_table_from_query {
  my( $self, $dba, $sql, @params ) = @_;
  return $self->_table_from_query( $self->my_table, $dba, $sql, @params );
}

sub _table_from_query {
  my( $self, $table, $dba, $sql, @params ) = @_;
  my $sth = $dba->prepare( $sql );
  $sth->execute( @params );

  my $html = $table
    ->add_columns(  map { {'key'=>$_} } @{ $sth->{'NAME'} } )
    ->add_data( @{$sth->fetchall_arrayref( {} )} )
    ->render;
  $sth->finish;
  return $html;
}

1;
