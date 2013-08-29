## Apache start-up script to preload in a number of modules
## required by the page templating scripts etc - to speed up
## process of producing children and to minimise amount of
## shared memory.
##
## Include the site specific library directory!
## Author         : js5
## Maintainer     : js5
## Created        : 2009-08-12
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

package Pagesmith::Startup;

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use File::Basename qw(dirname);
use Cwd qw(abs_path);

BEGIN {
  if( exists $ENV{q(SINGLE_LIB_DIR)} && $ENV{q(SINGLE_LIB_DIR)} ) {
    my $dir = dirname(dirname(dirname(abs_path(__FILE__)))).'/sld';
    if( -e $dir ) {
      unshift @INC, $dir;
      $ENV{'PERL5LIB'}||=q();
      $ENV{'PERL5LIB'} = qq($dir:$ENV{'PERL5LIB'}); ## no critic (LocalizedPunctuationVars)
    }
  } else {
    my $dir = dirname(dirname(abs_path(__FILE__)));
    if( -e $dir ) {
      unshift @INC, $dir;
      $ENV{'PERL5LIB'}||=q();
      $ENV{'PERL5LIB'} = qq($dir:$ENV{'PERL5LIB'}); ## no critic (LocalizedPunctuationVars)
    }
    $dir = dirname($dir).'/ext-lib';
    if( -e $dir ) {
      unshift @INC, $dir;
      $ENV{'PERL5LIB'}||=q();
      $ENV{'PERL5LIB'} = qq($dir:$ENV{'PERL5LIB'}); ## no critic (LocalizedPunctuationVars)
    }
  }
}

## A shed load of mod_perl modules to include
## either mod_perl or Apache2 stuff....

use ModPerl::Util (); ## for CORE::GLOBAL::exit

use Apache2::CmdParms;
use Apache2::Connection ();
use Apache2::Const '-compile' => ':common';
use Apache2::Directive;
use Apache2::Module;
use Apache2::Request ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Log ();
use Apache2::URI ();
use Apache2::Util ();
use Apache2::Upload ();

use APR::Const     '-compile' => ':common';
use APR::Table ();
use APR::Finfo ();

#?  use ModPerl::Registry (); ## May include this but not at the moment...


## Now for some of the core modules used by the page wrapper!

use Cache::Memcached::Tags; ## Used to access page templates etc
use Carp;
use URI::Escape;
#use CSS::Minifier;        ## To compress CSS
use Cwd;
use Data::Dumper;         ## To dump data structures for Debug
use Date::Format;         ## For displaying last modified information
use DBI;
use DBIx::Connector;
use Digest::MD5;          ## To compute checksums for temporary files
use Encode::Unicode;
use File::Basename;       ## To parse directory names...
#use File::Spec;
use HTML::Entities;       ## To convert &,",<,> etc to their appropriate HTML codes;
use HTML::HeadParser;     ## Used to parse HTML head to get out meta information
use HTML::Tidy;
use HTTP::Request;
use Image::Magick;
use Image::Size;
# use JavaScript::Minifier; ## To compress Javascript
use POSIX qw(floor ceil);
use Syntax::Highlight::HTML;
use Sys::Hostname;
use Text::Markdown;
use Text::MediawikiFormat;
use Text::ParseWords;
use Time::HiRes; ## Used in diagnostic timers...


## Now for the Pagesmith modules we will use

use Pagesmith::Apache::Decorate;
use Pagesmith::Apache::HTML;
use Pagesmith::Apache::Text;
use Pagesmith::Apache::Config;
use Pagesmith::Apache::Base;
use Pagesmith::Apache::Timer;
use Pagesmith::Apache::Markdown;
use Pagesmith::Apache::Wiki;
use Pagesmith::Apache::Errors;
use Pagesmith::Apache::Params;
use Pagesmith::Apache::Action;
use Pagesmith::Apache::TmpFile;

use Pagesmith::Adaptor::Reference;

use Pagesmith::Utils::Validator::XHTML;
use Pagesmith::Utils::Tidy;
use Pagesmith::Utils::Curl::Request;
use Pagesmith::Utils::Curl::Response;
use Pagesmith::Utils::Curl::Fetcher;

use Pagesmith::Component::Link;
use Pagesmith::Component::Param;
use Pagesmith::Component::FacultyImage;
use Pagesmith::Component::JsFile;
use Pagesmith::Component::EntryPortal;
use Pagesmith::Component::Zoom;
use Pagesmith::Component::Email;
use Pagesmith::Component::CssFile;
use Pagesmith::Component::TmpRef;
use Pagesmith::Component::FeatureImage;
use Pagesmith::Component::If;
use Pagesmith::Component::Cite;
use Pagesmith::Component::Gallery;
use Pagesmith::Component::References;
use Pagesmith::Component::End;
use Pagesmith::Component::Markedup;
use Pagesmith::Component::Flastmod;
use Pagesmith::Component::User;
use Pagesmith::Component::File;
use Pagesmith::Component::Image;
use Pagesmith::Component::YouTube;
use Pagesmith::Component::DataTable;

use Pagesmith::Cache::Base;
use Pagesmith::Cache::File;
use Pagesmith::Cache::SQL;
use Pagesmith::Cache::Memcache;

use Pagesmith::HTML::Table;
use Pagesmith::HTML::TwoCol;
use Pagesmith::HTML::Tabs;

use Pagesmith::Object::Reference;

use Pagesmith::Action::Developer::Raw;
use Pagesmith::Action::Error;
use Pagesmith::Action::Serverinfo;
use Pagesmith::Action::Delay;
use Pagesmith::Action::Ensembl;
use Pagesmith::Action::Link;
use Pagesmith::Action::Login;
use Pagesmith::Action::Logout;
use Pagesmith::Action::Feedback;
use Pagesmith::Action::Svg;
use Pagesmith::Action::Jft;
use Pagesmith::Action::Component;
use Pagesmith::Action::Dump;

use Pagesmith::Component;
use Pagesmith::ConfigHash;
use Pagesmith::Object;
use Pagesmith::Core;
use Pagesmith::Cache;
use Pagesmith::Action;
use Pagesmith::Message;
use Pagesmith::Page;
use Pagesmith::Root;
use Pagesmith::Adaptor;

1;
