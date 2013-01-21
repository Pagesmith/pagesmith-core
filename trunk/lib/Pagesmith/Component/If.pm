package Pagesmith::Component::If;

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

use base qw(Pagesmith::Component);

sub usage {
  my $self = shift;
  ## no critic (InterpolationOfMetachars)
  return {
    'parameters'  => q({variable} {condition} {values+}),
    'description' => 'Sets show/hide option for a block of HTML based on condition',
    'notes'       => [ 'Usually use with <%~ ~%> delayed directive style as usually want to cache content before if applied....',
      '{condition} values are =/==/eq/equals !/!=/ne/not_equals =~/~/contains_word !~/not_contains_word contains not_contains =^/starts !^/not_starts =$/ends !$/not_ends',
      '{variable}  is one of H:header_name or E:environment_variable',
      ] ,
    'see_also'    => { 'Pagesmith::Component::End' => 'End of block' },
  };
  ## use critic
}

sub execute {
  my $self = shift;
  my ( $variable, $condition, @T ) = $self->pars;

  my $rhs = "@T";

  $self->r->subprocess_env if $variable =~ m{\AE:}mxs;

  my $lhs =
      $variable =~ m{\AH:(.*)\Z}mxs ? $self->r->headers_in->get($1)
    : $variable =~ m{\AE:(.*)\Z}mxs ? $self->r->subprocess_env->get($1)
    :                              undef;

  $lhs = q() unless defined $lhs; # Value may be undefined so set it to blank if it is...

  my $f =
      $condition =~ m{\A(=|==|eq|equals)\Z}mxs       ? ( lc $lhs eq lc $rhs )
    : $condition =~ m{\A(!|!=|ne|not_equals)\Z}mxs   ? ( lc $lhs ne lc $rhs )
    : $condition =~ m{\A(=~|~|contains_word)\Z}mxs   ? ( $lhs =~ m{\b$rhs\b}mxis )
    : $condition =~ m{\A(!~|not_contains_word)\Z}mxs ? ( $lhs !~ m{\b$rhs\b}mxis )
    : $condition =~ m{\A(contains)\Z}mxs        ? ( $lhs =~ m{$rhs}mxis )
    : $condition =~ m{\A(not_contains)\Z}mxs      ? ( $lhs !~ m{$rhs}mxis )
    : $condition =~ m{\A(=\^|starts)\Z}mxs           ? ( $lhs =~ m{\A$rhs}mxis )
    : $condition =~ m{\A(!\^|not_starts)\Z}mxs       ? ( $lhs !~ m{\A$rhs}mxis )
    : $condition =~ m{\A(=\$|ends)\Z}mxs             ? ( $lhs =~ m{$rhs\Z}mxis )
    : $condition =~ m{\A(!\$|not_ends)\Z}mxs         ? ( $lhs !~ m{$rhs\Z}mxis )
    :                                                 0;
  return $f ? '<% show %>' : '<% hide %>';
}

1;

__END__

h3. Sytnax

<% If
  variable
  condition
  value
%>

h3. Purpose

Hide a block of HTML

h3. Options

None

h3. Notes

* Variable is either E:environment_variable or H:headers_in

* Condition is one of =|==|eq|equals; !|!=|ne|not_equals; =~|~|contains;
  !~|not_contains; =^|starts; !^|not_starts; =$|ends; !$|not_ends

* Usually use with <%~ ~%> delayed directive style as usually want to cache
  content before if applied....

h3. See Also

* Directive: End

h3. Examples

* <%~ If H:ClientRealm contains myrealm ~%> - Display up to corresponding

* <%~ End ~%> only if in My Realm....

h3. Developer Notes

* Make nesting work properly!
