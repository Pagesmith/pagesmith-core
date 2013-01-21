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

sub define_options {
  my $self = shift;
  return (
    $self->ajax_option,
    { 'code' => 'length',    'defn' => '=i', 'Restrict the length of the URL if the link is longer than this length' },
    { 'code' => 'get_title', 'description' => 'If set retrieve page and parse title from response' },
  );
}

sub usage {
  my $self = shift;
  return {
    'paramters'   => q({name=s}+),
    'description' => 'Push javascript files into the page (either as embed files or src links)',
    'notes'       => [q({name} name of file)],
  };
}

sub ajax {
  my $self = shift;
  return $self->default_ajax;
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
  return $self->safe_link( $url, $self->option( 'length' ), $extra );
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
