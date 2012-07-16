package Pagesmith::Form::Stage::Final;

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

use base qw( Pagesmith::Form::Stage );

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(encode_entities);
use List::MoreUtils qw(any);

sub is_invalid {
  my $self = shift;
#@return (boolean) false - Final stage always classes as valid
  return 0;
}
1;
