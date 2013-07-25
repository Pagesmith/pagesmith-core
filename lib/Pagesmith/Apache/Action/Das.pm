package Pagesmith::Apache::Action::Das;

## Apache handler for CGP action classes
## Author         : js5,dmb,pg6
## Maintainer     : pg6, dmb, nb7
## Created        : 2011-05-04
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$


use strict;
use warnings;
use utf8;

use version qw(qv);our $VERSION = qv('0.1.0');

use Const::Fast qw(const);

const my %LOOKUP => map { lc $_ => $_ } qw(Sources DSN Flush Summary Status);

use Pagesmith::Apache::Action qw(my_handler);

sub handler {
  my $r = shift;
  # return($path_munger_sub_ref,$request)
  # see Pagesmith::Action::_handler to find out how this works
  # briefly:  munges the url path using the sub {} defined here
  # to get the action module
  # then calls its run() method and returns a status value

  return my_handler(
    sub {
      my ( $apache_r, $path_info ) = @_;
      if( $path_info->[0] eq 'das' ) {
        shift @{$path_info};
        if( @{$path_info} ) {
          my $k = lc $path_info->[0];
          if( exists $LOOKUP{ $k } ) {
            $path_info->[0] = "Das_$LOOKUP{ $k }";
          } else {
            unshift @{$path_info}, 'Das';
          }
        } else {
          unshift @{$path_info}, 'Das';
        }
      }
      return;
    },
    $r,
  );
}

1;
