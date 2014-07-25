package Pagesmith::Action::Das::Status;

#+----------------------------------------------------------------------
#| Copyright (c) 2013, 2014 Genome Research Ltd.
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

## Monitorus proxy!
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-13
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action::Das Pagesmith::Support::Das);
use Time::HiRes qw(time);

sub run {
  my $self = shift;

  my $domain = $self->r->headers_in->{'Host'}||'das.sanger.ac.uk';
  ## no critic (LongChainsOfMethodCalls)
  my $start = time;
  my @res = $self->fetch_results( $domain, $self->get_sources( $domain ) );

  return $self->html->wrap( 'DAS status',
    sprintf '<p>Time to retrieve all URLS: %0.3f seconds</p>%s',
      time - $start,
    $self->table
      ->make_sortable
      ->add_class( 'before' )
      ->set_pagination( [qw(10 25 50 all)], '25' )
      ->set_export( [qw(csv xls)] )
      ->set_colfilter
      ->add_columns(
        { 'key' => 'duration',   'caption' => 'Duration', 'format' => 'f3' },
        { 'key' => 'error',      'caption' => 'Error',      'align' => 'c', },
        { 'key' => 'error_http', 'caption' => 'HTTP error', 'align' => 'c', },
        { 'key' => 'error_das', 'caption'  => 'DAS error',  'align' => 'c', },
        { 'key' => 'error_resp', 'caption' => 'Req error',  'align' => 'c', },
        { 'key' => 'error_code', 'caption' => 'Mismatch',   'align' => 'c', },
        { 'key' => 'http_code', 'caption' => 'HTTP code',   'align' => 'c' },
        { 'key' => 'das_code',  'caption' => 'DAS code',    'align' => 'c' },
        { 'key' => 'source',    'caption' => 'Source', },
        { 'key' => 'command',    'caption' => 'Command', },
        { 'key' => 'resp_type', 'caption' => 'Response type', },
        { 'key' => 'length',    'caption' => 'Length', 'format' => 'd' },
        { 'key' => 'l2',    'caption' => 'Length', 'format' => 'd' },
        { 'key' => 'servers',   'caption' => 'Servers', },
      )->add_data( @res )
      ->set_current_row_class([
       [ 'fatal', 'exact', 'error_http', 'HTTP', ],
       [ 'fatal', 'exact', 'error_das',  'DAS.',  ],
       [ 'fatal', 'exact', 'error_resp', 'REQ.', ],
       [ 'warn',  'exact', 'error_code', 'code', ],
       [ 'warn',  'exact', 'error_resp', 'resp', ],
       [ q() ],
      ])->render,
  )->ok;
  ## use critc
}

1;
