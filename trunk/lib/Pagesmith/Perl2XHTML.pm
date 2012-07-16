package Pagesmith::Perl2XHTML;


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

sub new {
  my $class = shift;
  my $self  = {
    'root'    => '/www/www-trunk',
    'parser'  => q(),
    'infile'  => q(),
    'outfile' => q(),
    'data'    => q(),
    'html'    => q(),
    'title'   => q(),
  };
  bless $self, $class;
  return $self;
}

1;

# parse with "javadoc" esq comments...

my @lines = <FH>;

my %doc_info;
while (@lines) {
  $_ = shift @lines;

  if (m{\A\s*sub\s(\w+)}mxs) {
    $current_sub = $1;
    $sub_start   = 1;
    push @subs, $current_sub;
    $doc_info{$current_sub}{
      'line_no'     => $line,
      'parameters'  => [],
      'return'      => q(),
      'description' => q(),
      'perl'        => $_
    };
    next;
  }
  if ( m{\A\#\#\s*(.*)\Z}mxs && $sub_start ) {
    $doc_info{$current_sub}{'description'} .= "$_ ";
    next;
  }
  if ( m{\A\#\@(\w+)(.*)\Z}mxs ) {
    if ( $1 eq 'param' ) {
      push @{ $doc_info{$current_sub}{'parameters'} }, $2;
    } elsif ( $1 eq 'return' ) {
      $doc_info{$current_sub}{'return'} = $1;
    }
    next;
  }
  if (m{\A__END__\Z}mxs) {
    last;
  }
  if ($current_sub) {
    $sub_start = 0;
    $doc_info{$current_sub}{'perl'} .= $_;
  }

}

1;

__END__
<html> < head > <title> Documentation for module : { {module_name} } </title> < /head>
  <body>
  <div class="main">
    <div class="panel">
      <h2>{{module_name}}</ h2 > <p> { {description} } </p> < dl class =
    "twocol" > <dt> Author
  : </dt> < dd > { {author} } </dd> < dt > Last updated
  : </dt> < dd > { {} } </dd> < dd > </dd> < dt > Revision no
  : </dt> < dd > { {} } </dd> < dt > SVN URL
  : </dt> < dd > { {} } </dd> < /dl>
    </ div > <div> < h3 > POD documentation </h3> < /div>
    <div class="panel">
      <h3>Documented source code</ h3 > </div> < /div>
  <div class="rhs">
    <div class="panel">
      <h3>Module tree</ h3 > </div> < div class = "panel" > <h3> Subroutines and methods </h3> < ul > <li> - &gt;
run() < /li>
        <li>-&gt;new()</ li > </ul> < /div>
    <div class="panel">
      <h3>Package globals</ h3 > <p> None </p> < /div>
  </ div >

