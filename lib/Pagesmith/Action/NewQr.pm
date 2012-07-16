package Pagesmith::Action::NewQr;

## Qr code
##  Experiment to look up a qr code given a url
##  Eventually we will allow setting.
## Author         : mw6
## Maintainer     : mw6
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action);

use Pagesmith::Adaptor::Qr;

sub qr_adaptor {
  my $self = shift;
  return $self->{'qr'} ||=
    Pagesmith::Adaptor::Qr->new( ); ### Need to check what parameters this expects.
}

sub run {
  my $self = shift;
  my $userid = $self->user->ldap_id || q(nobody);
  my $url    = $self->param('url') || q();
  my $qr     = $self->qr_adaptor->get_by_url($url) || {};
# $self->dumper($qr);
  if ($url && $userid && !$qr->{'code'}) {
    return $self->create_new_url();
  }

  my $qr_code = $qr->{'code'} || q(not found);

  # created_at
  # created_by
  my $creator = $qr->{'created_by'} || 'unknown';

## no critic (ImplicitNewlines)

  return $self->html->print( qq(
<form action="/action/NewQr" method="post">
  <p><label><em>User id</em></label><input type="text" name="userid" value="$userid" readonly="true" /></p>
  <label>Creator</label><input type="text" name="creator" value="$creator" readonly="true" />
  <label>URL to shorten (paste here)</label><input type="text" name="url" value="$url" />
  <label>Short code</label><input type="text" name="qcode" value="$qr_code" />
  <input type="submit">Submit form</input>
</form>) )->ok;
  ## use critic
  }

# if url lookup fails, and then code needs creating.
sub create_new_url {
  my $self = shift;
  my $userid = $self->user->ldap_id || q();
  my $url    = $self->param('url') || q();
  if (!$userid || !$url) {
    return $self->html->print( '<p>Error: Parameter not specified correctly</p>' )->ok;
  }
  if ($url !~ m{^http(s)?:\/\/}xms ) {
    return $self->html->print( '<p>Error: URL Parameter not specified correctly</p>' )->ok;
  }

  $self->{'qr'} = $self->qr_adaptor->create( { 'url'        => $url,
                                              'prime'      => 'probably',
                                              'created_at' => ( time ),
                                              'created_by' => $userid,
                                            } );
  $self->qr_adaptor->store();

  my $new_code = $self->{'qr'}->{'code'} || q{};
  $self->dumper($self->{'qr'});
  ## no critic (ImplicitNewlines)
  return $self->html->print( qq(
    <p>
      The url $url was not found in the database.
    </p>
    <p>
      We created a new qr code for this entry.
    </p>
    <p>
      It is $new_code
    </p>
  ))->ok;
  ## use critic

}

1;
