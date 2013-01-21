package Pagesmith::Component::LoremIpsum;

## Generate some random text
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

Readonly my $DEFAULT_WHAT   => 'words';

use Carp qw(carp);
use English qw(-no_match_vars $EVAL_ERROR);
use HTML::Entities qw(encode_entities);
use LWP::Simple qw($ua get);

use Pagesmith::ConfigHash qw(get_config);

use base qw(Pagesmith::Component);

my %valid = qw(
  words 30
  paras 5
  lists 3
  bytes 300
);

sub usage {
  my $self = shift;
  return {
    'parameters'  => '{amount=i} {what=s}?',
    'description' => 'Display a chunk of Lorem Ipsum text',
    'notes'       => [
      '{what} can be one of bytes, lists, paras, words',
    ],
  };
}

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'start', 'defn' => q(!), 'default' => 1,
      'description' => 'Indicate whether to add ;start - i.e. force data to be cut from start of lorem ipsum' },
  );
}

sub execute {

#@param (self)
#@return (html) class attribute string containing zoom_level class
## Simply grabs the zoom_level from the users cookie and returns the
## HTML fragment to set the approriate class on the page
  my $self = shift;

  my($amount,$what) = $self->pars;

  $what   = $DEFAULT_WHAT   unless defined $what && exists $valid{$what};
  $amount = $valid{$what}   unless $amount =~ m{\A\d+\Z}mxs;

  $ua->proxy( 'http', get_config( 'ProxyURL' ) );

  my $extra = $self->option('start') ? '&start=yes' : q();

  my $output = q(could not retrieve text);
  my $rv = eval {
    my $res = get sprintf 'http://www.lipsum.com/feed/xml?what=%s&amount=%s%s', $what, $amount, $extra;
    $output = $res =~  m{<lipsum>(.*)<\/lipsum>}mxs ? $1 : q(-);
    $output =
      join qq(\n), map {
        sprintf '<p>%s</p>',
        encode_entities($_)
      } split m{\n}mxs, $output if $what eq 'paras';
    $output =
      join qq(\n),
      map {
        sprintf '<ul><li>%s</li></ul>',
        join q(</li><li>),
        map {
          sprintf '%s.', encode_entities($_)
        }
        split m{[.]\s+}mxs, $_
      }
      split m{\n}mxs, $output if $what eq 'lists';
  };
  carp $EVAL_ERROR if $EVAL_ERROR;
  return $output;
}

1;

__END__

h3. Sytnax

<% LoremIpsum
  -start=(yes|no)
  amount
  what=(words|paras|bytes|lists)
%>

h3. Purpose

Displays a block of lorem ipsum - if paras, lists it is wrapped in html tags.

h3. Notes

None

h3. See Also

None

h3. Examples

* <% LoremIpsum %> - Default display

* <% LoremIpsum -start=no 300 words %> - Display a 300 word block

h3. Developer Notes

none
