package Pagesmith::Adaptor::BaseTree;

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

use base qw(Pagesmith::Adaptor);


### Tree fetchers and selectors!

## no critic (ImplicitNewlines)
sub get_node {
  my( $self, $table, $code ) = @_;
  return $self->row_hash( "select * from $table where code = ?", $code );
}
sub self_and_ancestors {
  my( $self, $table, $code, $prune_root ) = @_;
  my $ancestors = $self->all_hash(
    "select p.*
       from $table as n, $table as p
      where p.l <= n.l and p.r >= n.r and n.code = ?
      order by p.l",
    $code,
  );
  shift @{$ancestors} if $prune_root;
  return $ancestors;
}

sub ancestors {
  my( $self, $table, $code, $prune_root ) = @_;
  my $ancestors = $self->all_hash(
    "select p.*
       from $table as n, $table as p
      where p.l < n.l and p.r > n.r and n.code = ?
      order by p.l",
    $code,
  );
  shift @{$ancestors} if $prune_root;
  return $ancestors;
}

sub self_and_descendants {
  my( $self, $table, $code ) = @_;
  return $self->all_hash(
    "select p.*
       from $table as n, $table as p
      where p.l >= n.l and p.r =< n.r and n.code = ?
      order by p.l",
    $code,
  );
}

sub descendants {
  my( $self, $table, $code ) = @_;
  return $self->all_hash(
    "select p.*
       from $table as n, $table as p
      where p.l > n.l and p.r < n.r and n.code = ?
      order by p.l",
    $code,
  );
}

sub children {
  my( $self, $table, $code ) = @_;
  return $self->all_hash(
    "select p.*
       from $table as n, $table as p
      where p.parent_id = n.{$table}_id and n.code = ?
      order by p.l",
    $code,
  );
}

sub add_tree_node {
  my ( $self, $table, $extra_data ) = @_;
  ## Get root node!
  my $id;
  my $res = $self->conn->txn( sub {
    my @keys   = sort keys %{$extra_data};
    my $cols   = join q(,), @keys;
    my $quests = join q(,), map { q(?) } @keys;
    my ($r) = $_->selectrow_array( "select r from $table where l=1" ); ## Do we have a root node?
    if( $r ) { ## If we do insert a new entry at the end of the tree!
      if( $_->do( "insert into $table (l,r,parent_id,$cols) values (?,?,1,$quests)",
            {}, $r, $r+1, map { $extra_data->{$_} } @keys ) ) {
        $id = $_->last_insert_id(undef,undef,$table, $table.'_id' );
        $_->do( "update $table set r=? where l=1", {}, $r+2 );
      }
    } else {
      if( $_->do( "insert into $table (l,r,parent_id,$cols) values (1,2,0.$quests)",
            {}, map { $extra_data->{$_} } @keys ) ) {
        $id = $_->last_insert_id(undef,undef,$table, $table.'_id' );
      }
    }
  } );
  return $id;
}


sub merge_with_parent {
  my( $self, $table, $code ) = @_;
  return $self->conn->txn( sub {
    # Check node...
    my $node       = $_->selectrow_hashref( "select * from $table where code = ?",  {}, $code );
    return 'Unknown node'       unless $node;
    return q(Can't merge root)  if $node->{'l'} == 1;
    $_->do( "delete from $table where code = ?", {}, $node->{'id'} );
    ## Get grandparent_id...
    my ($parent_id) = $self->selectall_array("select parent_id from $table where id = ?", $node->{'parent_id'});
    $_->do( "update $table set parent_id = ? where parent_id = ?", {}, $parent_id, $node->{'id'} );
    $_->do( "update $table set l = l -  if( l>?, 2, 1) where l > ?", {}, $node->{'l'}, $node->{'r'} );
    $_->do( "update $table set r = r -  if( l>?, 2, 1) where r > ?", {}, $node->{'l'}, $node->{'r'} );
  });
}

sub merge_with_previous_sibling {
  my( $self, $table, $code ) = @_;
  return $self->conn->txn( sub {
    # Check node...
    my $node       = $_->selectrow_hashref( "select * from $table where code = ?",  {}, $code );
    return 'Unknown node'             unless $node;
    return q(Can't merge root)        if $node->{'l'} == 1;
    my ($previous_sibling_id) = $_->selectrow_array( "select ${table}_id from $table where r = ?", {}, $node->{'l'}-1 );
    return q(Can't merge first node!) unless $previous_sibling_id;

    $_->do( "delete from $table where code = ?",       {}, $code );
    $_->do( "update $table set l = l - 2 where l > ?", {}, $node->{'l'} );
    $_->do( "update $table set r = r - 2 where r > ?", {}, $node->{'l'} );
    $_->do( "update $table set parent_id = ? where parent_id = ?",   {}, $previous_sibling_id, $node->{'id'} );
    $_->do( "update $table set r = ? where ${table}_id = ?",         {}, $node->{'r'}-2, $previous_sibling_id );
  });
}

sub prune_tree {
  my ( $self, $table, $code, $force ) = @_;
  return $self->conn->txn( sub {
    # Check node...
    my $node       = $_->selectrow_hashref( "select * from $table where code = ?",  {}, $code );
    return 'Unknown node'       unless $node;
    my $w = $node->{'r'}-$node->{'l'}+1;
    return 'Non-empty'          unless $force || $width == 2;
    $_->do( "delete from $table where l >= ? and l <= ?", {}, $w, $node->{'l'},$node->{'r'} );
    $_->do( "update $table set l = l - ? where l >= ?", {}, $w, $node->{'r'} );
    $_->do( "update $table set r = r - ? where r >= ?", {}, $w, $node->{'r'} );
    return;
  });
}

sub push_child {
  my ( $self, $table, $code, $parent_code ) = @_;
  # Position tree to have it's new left = to the right of it's parent!
  return $self->move_node( $table, $code, $parent_code, 'r', $table.'_id' );
}
sub before_node {
  my( $self, $table, $code, $sibling ) = @_;
  # Position tree to have it's new left = the left of it's sibling...
  return $self->move_node( $table, $code, $sibling_code, 'l', 'parent_id' );
}

## no critic (ManyArgs)
sub move_node {
  my ($self, $table, $code, $dest, $pos_col, $par_col ) = @_;
  return $self->conn->txn( sub {
    # Check node...
    my $node       = $_->selectrow_hashref( "select * from $table where code = ?",  {}, $code );
    return 'Unknown node'       unless $node;

    my ($new_left,$parent_id) = $_->selectrow_array("select $pos_col, $par_col from $table where code = ?", {}, $dest );
    return 'Unknown desination' unless $new_left;

    ## Do not perform move
    return 'Illegal move'       if $new_left >= $node->{'l'} && $new_left <= $node->{'r'};

    my $w = $node->{'r'} - $node->{'l'} + 1;
    my $d = $new_left - $node->{'l'};
    my $r = $node->{'r'};
    my $p = $node->{'l'};
    if( $d < 0 ) {
      $d -= $w;
      $p += $w;
    }
    $_->do( "update $table set parent_id = ? where ${table}_id = ?", {}, $parent_id, $node->{$table.'_id'} );
    $_->do( "update $table set l = l + ? where l >= ?", {}, $w, $new_left );
    $_->do( "update $table set r = r + ? where r >= ?", {}, $w, $new_left );
    $_->do( "update $table set l = l + ?, r = r + ? where l >= ? and r < ?", {}, $d, $d, $p, $p + $w );
    $_->do( "update $table set l = l - ? where l > ?", {}, $w, $r );
    $_->do( "update $table set r = r - ? where r > ?", {}, $w, $r );
    return;
  });
}
## use critic
1;

