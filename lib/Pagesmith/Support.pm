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
use POSIX qw(floor);
use Apache2::Request;

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Session::User;
use Pagesmith::HTML::Table;
use Pagesmith::HTML::Tabs;
use Pagesmith::HTML::TwoCol;

use Date::Format qw(time2str);

use Const::Fast qw(const);
const my $K      => 1_024;
const my $SIZE_R => 2;
## empty constructor!

## Code that requires r!

sub remote_ip {
  my $self = shift;
  return unless $self->r && $self->r->connection;
  return $self->r->connection->remote_ip if $self->r->connection->can('remote_ip');
  return $self->r->connection->client_ip if $self->r->connection->can('client_ip');
  return;
}

sub tmp_dumper {
  my( $self, $filename, $data_to_dump, $name_of_data ) = @_;
  $filename =~ s{[^-\w.]}{}mxsg;
  if( open my $fh, q(>), get_config( 'RealTmp').$filename ) {
    ## no critic (RequireChecked)
    print {$fh} $self->raw_dumper( $data_to_dump, $name_of_data );
    close $fh;
    ## use critic
  }
  return $self;
}

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
  return unless $self->r;
  $self->r->headers_out->set( 'X-Pagesmith-NavPath', $path );
  return $self;
}

sub is_web {
  my $self = shift;
  return $self->r ? 1 : 0;
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
  my $url = join q(://),
    $self->r->headers_in->{'X-is-ssl'} ? 'https' : 'http',
    $self->r->headers_in->{'Host'};
  if( $self->r->headers_in->{'X-is-ssl'} ) {
    $url =~ s{:443\Z}{}mxs;
  } else {
    $url =~ s{:80\Z}{}mxs;
  }
  return $url;
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

sub set_body_class {
  my( $self, $class ) = @_;
  $self->r->pnotes('body_class', $class );
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
  my( $self, $options ) = shift;
  $self->{'_apr'} ||= Apache2::Request->new( $self->r, %{$options||{}} );
  return $self->{'_apr'};
}

## Functions which generate a table from an SQL query - useful for testing!

sub table_from_query {
  my( $self, $dba, $sql, @params ) = @_;
  return $self->base_table_from_query( $self->table, $dba, $sql, @params );
}

sub my_table_from_query {
  my( $self, $dba, $sql, @params ) = @_;
  return $self->base_table_from_query( $self->my_table, $dba, $sql, @params );
}

sub base_table_from_query {
  my( $self, $table, $dba, $sql, @params ) = @_;
  my $sth = $dba->prepare( $sql );
     $sth->execute( @params );

  my $html = $table
    ->add_columns(  map { {'key'=>lc $_,'caption'=>$_} } @{ $sth->{'NAME'} } )
    ->add_data( @{$sth->fetchall_arrayref( )} )
    ->render;
  $sth->finish;
  return $html;
}

sub cache {
  my( $self, @params ) = @_;
  return Pagesmith::Cache->new( @params );
}

sub table {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::Table->new( $self->r, @pars );
}

sub twocol {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::TwoCol->new( @pars );
}

sub tabs {
  my( $self, @pars ) = @_;
  return Pagesmith::HTML::Tabs->new( @pars );
}

sub fake_tabs {
  my( $self, @pars ) = @_;
  return $self->tabs( @pars )->set_option( 'fake', 1 );
}

sub hidden_tabs {
  my( $self, @pars ) = @_;
  return $self->fake_tabs->add_classes('hidden');
}

sub second_tabs {
  my( $self, @pars ) = @_;
  return $self->fake_tabs->add_classes('second-tabs')->set_option( 'no_heading', 1 );
}

sub panel {
  my( $self, @html ) = @_;
  my @class = q(panel);
  push @class, @{shift @html}  if ref $html[0];
  return sprintf '<div class="%s">%s</div>', "@class", join q(), @html;
}

sub links_panel {
  my( $self, $heading, $links ) = @_;
  return unless @{$links};
  return $self->panel( sprintf '<h3>%s</h3><ul>%s</ul>',
    $heading, join q(), map { sprintf '<li><a href="%s">%s</a></li>', @{$_} } @{$links} );
}

sub format_date_range {
  my( $self, $start, $end ) = @_;
  return time2str( '%o %h %Y', $self->munge_date_time( $start ) ) if $start eq $end;
  my ( $sy, $sm, $sd ) = split m{-}mxs, $start;
  my ( $ey, $em, $ed ) = split m{-}mxs, $end;
  my $template = $sy != $ey ? '%o %B %Y'
               : $sm != $em ? '%o %B'
               :              '%o'
               ;
  return sprintf '%s - %s', time2str( $template, $self->munge_date_time( $start ) ),
                            time2str( '%o %B %Y', $self->munge_date_time( $end ) );
}

sub format_fixed  {
  my( $self, $size, $unit, $prec ) = @_;
  $prec ||= 0;
  $size ||= 0;
  my $sign = $size < 0 ? q(-) : q();
  $size = abs $size;
  $size /= $K;
  $size /= $K unless $unit eq 'k';
  return sprintf "%s%0.${prec}f%s", $sign, $size, uc $unit;
}

sub format_size {
  my( $self, $size, $prec ) = @_;
  $prec ||= 0;
  $size ||= 0;
  my $sign = $size < 0 ? q(-) : q();
  $size = abs $size;
  return '0' if $size == 0;
  my $index = floor( log( $size / $SIZE_R ) / log $K );
  return sprintf '%s%d', $sign, $size if $index < 1;
  $size /= $K**$index;
  my @suffix = qw/B K M G T P E Z Y/;

  return sprintf "%s%0.${prec}f%s", $sign, $size, $suffix[ $index ];
}

sub button_links {
  my( $self, @links ) = @_;
  my @link_pairs;
  push @link_pairs, [ splice @links,0,2 ] while @links;
  return sprintf '<p class="r">%s</p>',
    join '&nbsp; ',
    map { sprintf '<a class="btt no-img" href="%s">%s</a>', $self->encode( $_->[0] ), $self->encode( $_->[1] ) }
        @link_pairs;
}
1;

