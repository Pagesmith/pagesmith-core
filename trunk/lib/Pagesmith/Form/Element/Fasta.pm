package Pagesmith::Form::Element::Fasta;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------

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

use Const::Fast qw(const);
const my $DEFAULT_ROWS => 10;
const my $DEFAULT_COLS => 60;
const my $MAX_SEQ_TO_LIST => 10;
const my $MAX_SEQ_LENGTH_TO_SHOW => 200;


my $units = { map { $_ => 1 } qw(ids characters words) };
use base qw( Pagesmith::Form::Element::TextFile );

use HTML::Entities qw(encode_entities);
use List::Util qw(sum);
use List::MoreUtils qw(pairwise);

### Textarea element;

sub res {
  my( $self, $seq ) = @_;
  return $seq =~  tr{[a-z*A-Z]}{[a-z*A-Z]} ;
}
sub render_widge_readonly {
  my $self = shift;
  return '&nbsp' unless $self->value;

  my @parts = split m{(^>[^\n]+)}mxs, $self->value;

  return 'No sequence' unless @parts;

  my @headers   = map { m{\A>(.*?)\s*\Z}mxs ? $1 : $_ } grep { m{\A>}mxs } @parts;
  my @sequences = map { { 'name' => q(), 'seq' => $_, 'len' => $self->res($_), } } grep { !m{\A>}mxs } @parts;

  return 'No sequence' unless @sequences;

  if( $sequences[0]{'len'} ) {
    unshift @headers, 'Unnamed sequence';
  } else {
    shift @sequences;
  }
  my $c = 0;
  $sequences[ $c++ ]{'name'} = $_ foreach @headers;

  my $n_seq = @sequences;
  my $t_seq = sum map { $_->{'len'} } @sequences;

  my $return = sprintf 'There are %d sequences (totalling %d bps/aa)', $n_seq, $t_seq;

  return $return if $n_seq > $MAX_SEQ_TO_LIST;
  return sprintf '%s<ul>%s</ul>', $return,
    join q(), map { sprintf '<li>%s (%d bps/aa)</li>', $_->{'name'}, $_->{'len'} } @sequences;
  # return encode_entities( $self->value );
}

1;
