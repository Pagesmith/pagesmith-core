package Pagesmith::Object::Feedback;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2014 Genome Research Ltd.
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

use base qw(Pagesmith::BaseObject);

sub new {
  my($class,$adaptor,$feedback_data) = @_;
     $feedback_data    ||= {};
  my $self    = {
    'adaptor'    => $adaptor,
    'page'       => $feedback_data->{'page'},
    'created_at' => $feedback_data->{'created_at'},
    'created_by' => $feedback_data->{'created_by'},
    'comment'    => $feedback_data->{'comment'},
    'ip'         => $feedback_data->{'ip'},
    'useragent'  => $feedback_data->{'useragent'},
  };
  bless $self, $class;
  return $self;
}

sub page {
  my $self = shift;
  return $self->{'page'};
}

sub created_at {
  my $self = shift;
  return $self->{'created_at'};
}

sub created_by {
  my $self = shift;
  return $self->{'created_by'};
}

sub comment {
  my $self = shift;
  return $self->{'comment'};
}

sub ip {
  my $self = shift;
  return $self->{'ip'};
}

sub useragent {
  my $self = shift;
  return $self->{'useragent'};
}

sub store {
  my $self = shift;
  return $self->{'adaptor'}->store($self);
}
1;
