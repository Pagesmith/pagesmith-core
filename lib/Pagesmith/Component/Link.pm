package Pagesmith::Component::Link;

## Component to insert "escaped email addresses"
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
Readonly my $TIMEOUT => 2;

use Pagesmith::ConfigHash qw(get_config);

use base qw(Pagesmith::Component);

use LWP::Simple qw($ua get);

sub ajax {
  my $self = shift;
  return 0 unless $self->option('ajax');
  return 1;
}

sub execute {
  my $self = shift;
  my ($url) = $self->pars;
  my $extra = {};
  if( $self->option( 'get_title' ) ) {
    $ua->proxy( [qw(http https)], get_config( 'ProxyURL' ) );
    $ua->timeout( $TIMEOUT );
    my $response = get $url;
    $extra->{'template'} = '%%title%% (%%url%%)';
    if( ! $response ) {
      $extra->{'title'} = 'Page returns no content';
    } elsif( $response =~ m{<title>(.*?)</title>}mxs ) {
      $extra->{'title'} = $1;
    } else {
      $extra->{'title'} = 'Untitled';
    }
  }
  return $self->_safe_link( $url, $self->option( 'length' ), $extra );
}

1;

__END__

h3. Sytnax

<% Link
  -length=N
  url
%>

h3. Purpose

To insert a link into a webpage, but trim the middle out of the link as
displayed in the page if the URL is too long e.g:

  http://www.test.com/thi...est.html

h3. Options

* length (opt) - Length of text links
