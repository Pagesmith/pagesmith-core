package Pagesmith::Action::RequestCreate;

## RequestCreate a new account
##  html form to sumbit username/password to P::Utils::NewAccount
## Author         : mw6
## Maintainer     : mw6
## Created        : 2012-01-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Action);

use Pagesmith::Utils::NewAccount;

sub run {
  my $self = shift;
  my $user = $self->param('user') || q();
  my $password = $self->param('password') || q();
##no critic (ImplicitNewlines)
  my $string = qq(
  <p>Warn: This code is broken as P:U:NewAccount requests a new account but doesn't use the correct request structure</p>
<form action='/action/RequestCreate/' method='post'>
  <label>username</label><input type='text' name='user' value='$user' />
  <label>password</label><input type='text' name='password' value='$password' />
  <input type='submit' />
</form>);
##use critic (ImplicitNewlines)
  if ($user && $password) {
    my $acct = Pagesmith::Utils::NewAccount->new({'user'=>$user,'password'=>$password});
    my $result = $acct->check_new_user();
    if (!ref $result) {
      $string .= qq(<font color="red">$result</font>);
    } else {
      $string .= $self->per_dumper( $act->{'details'} );
    }
  }
  return $self->html->print( $string )->ok;
}

1;
