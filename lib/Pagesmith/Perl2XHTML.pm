package Pagesmith::Perl2XHTML;

#+----------------------------------------------------------------------
#| Copyright (c) 2010, 2011, 2012, 2013, 2014 Genome Research Ltd.
#| This file is part of the Pagesmith web framework.
#+----------------------------------------------------------------------
#| The Pagesmith web framework is free software: you can redistribute
#| it and/or modify it under the terms of the GNU Lesser General Public
#| License as published by the Free Software Foundation; either version
#| 3 of the License, or (at your option) any later version.
#|
#| This program is distributed in the hope that it will be useful, but
#| WITHOUT ANY WARRANTY; without even the implied warranty of
#| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#| Lesser General Public License for more details.
#|
#| You should have received a copy of the GNU Lesser General Public
#| License along with this program. If not, see:
#|     <http://www.gnu.org/licenses/>.
#+----------------------------------------------------------------------


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
  if ( m{\A[#]{2}\s*(.*)\Z}mxs && $sub_start ) {
    $doc_info{$current_sub}{'description'} .= "$1 ";
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

