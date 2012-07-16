package Pagesmith::Utils::SHTML;

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

use HTML::Entities qw(encode_entities);
use Encode::Unicode;

sub new {
  my ($class,@pars ) = @_;
  my $self  = {
    '_flag' => @pars ? $pars[0] : 1,
    '_vars' => {},
  };
  bless $self, $class;
  return $self;
}

sub parse {
  my $self     = shift;
  my $html     = shift;
  my $new_html = ${$html};
  $new_html =~ s{<fieldset(.*?)>(.*?)<x\/fieldset>}{$self->_fieldset($2)}mxgse;
  $new_html =~ s{<!--\#(.*?)-->}{$self->_directive($1)}mxgse;
  return \$new_html;
}

sub _fieldset {
  my ( $self, $str ) = @_;
  $str =~ s{<legend>(.*?)</legend>}{}mxs;
  if ($1) {
    my $t = $1;
    $str =~ s{\A\s+}{}mxs;
    $str =~ s{\s+\Z}{}mxs;
    return sprintf qq(\n<div class="fieldset">\n  <h3>%s</h3>\n  %s\n</div>), $t, $str;
  } else {
    return sprintf qq(\n<div class="fieldset">\n  %s\n</div>), $_;
  }
}

sub _directive {
  my ( $self, $str ) = @_;
  $str =~ s{\A\s+}{}mxs;
  my ( $cmd, $pars ) = split m{\s+}mxs, $str, 2;
  if ( $cmd eq 'set' ) {
    my ($param_name) = $pars =~ m{var="(.*?)"}mxs;
    my ($param_val) = $pars =~ m{value="(.*?)"}mxs;
    $self->{'_vars'}{$param_name} = $param_val;
  } elsif ( $cmd eq 'include' ) {
    if ( $pars =~ m{virtual="/perl/header"}mxs ) {
      my $html = "<html>\n<head>";
      my $t = $self->{'header_global'} ? $self->{'header_global'}->val( 'general', 'title' ) : q();
      $html .= sprintf "\n  <title>%s</title>", encode_entities($t) if $t;
      $html .= "\n</head>\n<body>";
      $html .= "\n  <h1>" . $self->{'_vars'}{'banner'} . '</h1>' if $self->{'_vars'}{'banner'};
      return $html;
    } elsif ( $pars =~ m{virtual="/perl/footer"}mxs ) {
      return sprintf "%s\n</body>\n</html>", $self->{'js'};
    } elsif ( $pars =~ m{(virtual|file)\s*=\s*"(.*?)"}mxs ) {
      ( my $file = $2 ) =~ s{\.shtml\Z}{\.inc}mxs;
      return sprintf '<%% File "%s" %%>', $file;
    }
  } else {
    return "DIRECTIVE $cmd";
  }
  return q();
}
1;
