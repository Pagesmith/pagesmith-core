package Pagesmith::Utils::CodeWriter::Relationship;

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

use List::MoreUtils qw(any);

## no critic (ExcessComplexity)
sub create {
  my ($self,$type) = @_;
  my $filename = sprintf '%s/Adaptor%s/%s.pm',$self->base_path,$self->ns_path, $self->fp( $type );

  my $type_ky             = $self->ky( $type );
  my $conf                = $self->conf('relationships',$type);
  my $table_name          = $type_ky;
  $_->{'alias'}         ||=$_->{'type'} foreach @{$conf->{'objects'}||[]};  ## Hack to force alias onto each object even if not defined!

  my @unique_cols         = grep {  $_->{'index'} } @{$conf->{'properties'}}; ## Columns which are part of the unique index!
  my @value_cols          = grep { !$_->{'index'} } @{$conf->{'properties'}}; ## Columns which are not!

  my $obj_column_names      = join qq(,\n           ),                                map { $self->id($_->{'alias'})        } @{$conf->{'objects'}||[]};
  my $where_obj             = join qq(,\n           ),                                map { $self->id($_->{'alias'}).' = ?' } @{$conf->{'objects'}||[]};

  ## no critic (InterpolationOfMetachars)
  my $obj_parameters        = join qq(,\n           ),
                              map { sprintf q(exists $params->{'%1$s'} ? $params->{'%1$s'} : $params->{'%2$s'}->%3$s),
                                $self->id($_->{'alias'}), $self->ky($_->{'alias'}), $self->id($_->{'type'}) } @{$conf->{'objects'}||[]};
  ## use critic
  my $data_parameters       = join q(), map { sprintf qq(\$params->{'%s'},\n           ), lc $_->{'code'} } @{$conf->{'properties'}||[]};
  my $data_column_names     = join q(), map { sprintf qq(,\n           rel.%s), $_ } map { lc $_->{'code'} } @{$conf->{'properties'}||[]};
  my $ins_data_column_names = join q(), map { sprintf qq(%s,\n           ), $_     } map { lc $_->{'code'} } @{$conf->{'properties'}||[]};
  my $upd_data_column_names = join qq(,\n           ),                                map { lc $_->{'code'}.' = ?' } @{$conf->{'properties'}||[]};

  ## Create get_all calls
  my @full_fetch_cols     = map { $_->{'alias'} } @{$conf->{'objects'}};
  my %fetch_groups        = %{$conf->{'fetch_by'}||[]};
      $fetch_groups{q(_)} = [];                     ## Fetch everything
      $fetch_groups{q(.)} = [ @full_fetch_cols ];   ## Fetch entries for all objects!
      $fetch_groups{q(!)} = [ @full_fetch_cols, map { $_->{'code'} } @unique_cols ] if @unique_cols; ## Fetch a single row!
  my $fetch_methods = q();
  foreach my $by ( sort keys %fetch_groups ) {
    my @types          = @{$fetch_groups{$by}||[]};  ## These are object types that we are going to include
    my %h_types        = map { ($_, m{\A[[:upper:]]}mxs ? 'Object' : 'value' ) } @types;
    my @tables         = grep { !exists $h_types{$_->{'alias'}} } @{$conf->{'objects'}};

    my $single_value   = @tables                                             ? 0
                       : (any { !exists $h_types{$_->{'code'}} } @unique_cols) ? 0
                       :                                                       1
                       ;
    my $method_name     = $by eq q(!) ? "get_one_$type_ky"
                        : $by eq q(_) ? "get_all_$type_ky"
                        : $by eq q(.) ? "get_$type_ky"
                        :               "get_${type_ky}_by_".join q(_), map { $self->ky( $_ ) } split m{_}mxs, $by
                        ;

    my $extra_pars     = join q(),   map { sprintf ', $%s', $self->ky($_) } @types; ## no critic (InterpolationOfMetachars)
    my $tables         = join q(, ), "$table_name as rel",
      map { $_->{'type'} eq $_->{'alias'}
          ? $self->ky($_->{'type'})
          : sprintf '%s %s', $self->ky($_->{'type'}),$self->ky($_->{'alias'}) } @tables;
    my @where_cols     = map { sprintf 'rel.%s=?', $h_types{$_} eq 'Object' ? $self->id($_) : $_ }                @types;   ## Restrict
    push @where_cols,    map { sprintf 'rel.%1$s=%2$s.%1$s', $self->id($_->{'alias'}), $self->ky($_->{'alias'}) } @tables;  ## no critic (InterpolationOfMetachars) # Join in table!
    my $where_cols = @where_cols ? sprintf "\n     where %s", join qq(,\n           ), @where_cols : q();
    my @object_cols;
    my $sql_pars       = q();
    my $sql_pars_x     = q();
    my $param_doc_string = q();
    foreach my $obj_ref (@{$conf->{'objects'}}) {
      my $alias = $self->ky($obj_ref->{'alias'});
      if( exists $h_types{$obj_ref->{'alias'}} ) {
        ## Object used in filter
        $param_doc_string .= sprintf qq(\n#\@param (Pagesmith::Adaptor::%s::%s|integer) %s), $self->namespace, $obj_ref->{'type'}, $alias;
        $sql_pars   .= sprintf ",\n    ref \$%1\$s ? \$%1\$s->id : \$%1\$s", $alias;
        $sql_pars_x .= sprintf ",\n    \$%s->id",   $alias;
        my $cols    =  sprintf '? as %s_id', $alias;
        foreach ( grep { any { $_ eq 'hr_name' } @{$_->{'flags'}||[]} } @{$self->conf('objects',$obj_ref->{'type'},'properties')||[]} ) {
          $sql_pars .= ",\n". sprintf '    ref $%1$s ? $%1$s->%2$s : q(-)',   $alias, $_->{'function'} || $_->{'code'};## no critic (InterpolationOfMetachars)
          $cols     .= sprintf ', ? as %s_%s', $alias, $_->{'code'};
        }
        push @object_cols, $cols;
      } else {
        ## Object used in join
        my $cols = sprintf 'rel.%s_id', $alias;
        foreach ( grep { any { $_ eq 'hr_name' } @{$_->{'flags'}||[]} } @{$self->conf('objects',$obj_ref->{'type'},'properties')||[]} ) {
          $cols     .= ",\n". sprintf '           %1$s.%2$s as %1$s_%2$s', $alias, $_->{'code'}; ## no critic (InterpolationOfMetachars)
        }
        push @object_cols, $cols;
      }
    }
    foreach my $col_ref (grep { exists $h_types{$_->{'code'}} } @unique_cols ) {
      $param_doc_string .= sprintf qq(\n#\@param (scalar) %s), $col_ref->{'code'};
      $sql_pars_x .= sprintf ",\n    \$%s", $col_ref->{'code'};
    }
    my $object_cols = join ",\n           ", @object_cols;
    my $object_vals = "$sql_pars$sql_pars_x";
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
    $fetch_methods .= sprintf q(
sub %1$s {
#@param (self)%11$s
#@returns %9$s
## Fetch %10$s from database
  my( $self%2$s )  = @_;
  my $sql = '
    select %3$s'.$DATA_COLUMNS.'
      from %4$s%5$s';
  return $self->%6$s( $sql%7$s )%8$s;
}
),
      $method_name,
      $extra_pars,
      $object_cols,
      $tables,
      $where_cols,
      $single_value ? 'hash' : 'all_hash',
      $object_vals,
      $single_value ? q()    : q(||[]),
      $single_value ? q((hash)?) : q((hash[])),
      $single_value ? 'single row' : 'arrayref of rows',
      $param_doc_string;
#@endraw
## use critic
  }
  my $names_obj = q();
  ( my $question_marks_obj = $obj_column_names.$ins_data_column_names ) =~ s{[^,]+}{?}mxsg;
  my $update_prop = q();
  my $values_prop = q();
  my $values_obj  = q();
## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $store_and_update_methods = sprintf q(
sub store {
#@params (self) ()
#@return (boolean)
## Store value of relationship in database
  my( $self, $pars ) = @_;

  my $sql = '
    insert ignore into %1$s
         ( %2$s )
  values ( %3$s )';

  $self->query( $sql,%4$s,
  );
  return $self->update( $pars );
}

sub update {
#@params (self) (hash)
#@return (boolean)
## Store value of relationship in database
  my( $self, $pars ) = @_;

  my $sql = '
    update %1$s
       set %5$s
     where %6$s';

  return $self->query( $sql,%4$s,
  );
}
), $type_ky,                                  ## %1$s
   $ins_data_column_names.$obj_column_names,  ## %2$s
   $question_marks_obj,                       ## %3$s
   $data_parameters.$obj_parameters,          ## %4$s
   $upd_data_column_names,                    ## %5$s
   $where_obj,                                ## %6$s
   $values_prop,                              ## %7$s
   ;#$parameters;                               ## %8$s

  my $perl = sprintf q(package Pagesmith::Adaptor::%1$s::%2$s;

## Adaptor for relationship %2$s in namespace %1$s
%3$s
use base qw(Pagesmith::Adaptor::%1$s);

use Const::Fast qw(const);
## no critic (ImplicitNewlines)

const my $DATA_COLUMNS => q(%4$s);

## ----------------------------------------------------------------------
## Store and update methods
## ----------------------------------------------------------------------
%5$s
## ----------------------------------------------------------------------
## Fetch methods
## ----------------------------------------------------------------------
%6$s
## use critic

1;

__END__

Purpose
-------

Relationship adaptors like this represent relationships between core objects
(without themselves being objects). Many pairs of objects may have multiple
relationships between them.

),
    $self->namespace,           ## %1$s
    $type,                      ## %2$s
    $self->boilerplate,         ## %3$s
    $data_column_names,         ## %4$s
    $store_and_update_methods,  ## %5$s
    $fetch_methods,             ## %6$s
    ;
#@endraw
## use critic

  return $self->write_file( $filename, $perl );
}

1;

