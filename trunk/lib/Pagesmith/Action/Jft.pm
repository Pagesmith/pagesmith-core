package Pagesmith::Action::Jft;
## Handles code for the File tree!
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

use base qw(Pagesmith::Action);

use Cwd qw(realpath);
use Date::Format qw(time2str);
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use File::Spec;
use HTML::Entities qw(encode_entities);
use HTML::HeadParser;    ## Used to parse the HTML header
use Image::Size qw(imgsize);

use Const::Fast qw(const);
const my $TIME_FMT => '%a, %d %b %Y %H:%M %Z';
#----------------------------------------------------------

my %ext_map = (
  'app'    => ['Application',          qw(bat com exe)],
  'code'   => ['Source code',          qw(afp afpa asp aspx c cfm cgi cpp h lasso vb xml)],
  'css'    => ['CSS',                  qw(css)],
  'db'     => ['Database',             qw(sql)],
  'doc'    => ['Microsoft Word',       qw(doc docx)],
  'film'   => ['Video',                qw(3gp avi mov mp4 mpg mpeg wmv)],
  'fla'    => ['Flash',                qw(fla swf)],
  'html'   => ['HTML',                 qw(htm html thtml whtml mhtml inc)],
  'img'    => ['Image',                qw(bmp gif jpg jpeg pcx png tif tiff)],
  'java'   => ['Java',                 qw(jar java)],
  'linux'  => ['Linux install',        qw(rpm deb)],
  'music'  => ['Audio',                qw(m4p mp3 ogg wav)],
  'pdf'    => ['Adobe Acrobat',        qw(pdf)],
  'php'    => ['PHP',                  qw(php)],
  'ppt'    => ['Microsoft powerpoint', qw(ppt)],
  'psd'    => ['Adobe Photoshop',      qw(psd)],
  'ruby'   => ['Ruby',                 qw(rb rbx rhtml)],
  'script' => ['Script',               qw(js pl py pm perl)],
  'txt'    => ['Text',                 qw(log txt text ini cfg)],
  'xls'    => ['Microsoft excel',      qw(xls xlsx)],
  'zip'    => ['Compressed',           qw(zip bz2 gz tar tgz)],
);

my %types;
my %types_desc = ( 'unknown' => 'Unknown file format' );
foreach my $k ( keys %ext_map ) {
  my ( $v, @Q ) = @{ $ext_map{$k} };
  $types_desc{$k} = $v;
  $types{$_} = $k foreach @Q;
}

##no critic (ExcessComplexity)
sub run {
  my $self = shift;
  my $root = $self->r->document_root;
  my $dir  = $self->param('dir');
  $dir =~ s{\A/}{}mxs;
  my $full_dir = realpath( File::Spec->rel2abs( $dir, $root ) );
  return $self->not_found unless -e $full_dir;    ## Check exists and database
  if ( -d $full_dir && $self->r->method eq 'POST' ) {
    $dir = "$dir/" unless $dir =~ m{/\Z}mxs;
    $dir =~ s{\A/}{}mxs;
    $full_dir .= q(/);
    return $self->forbidden unless substr( $full_dir, 0, length $root ) eq $root;    ## Check it is in the specified directories
    my $bin;
    return $self->forbidden unless opendir $bin, $full_dir;    ## Die unless exists!!
    my @files = ( [], [] );
    my $total = 0;
    while ( defined( my $file = readdir $bin ) ) {
      next if $file eq q(.) or $file eq q(..);
      next if $file =~ m{(^[.]|(~|[.]bak)$)}mxs;
      $total++;
      if ( -d "$full_dir$file" ) {
        push @{ $files[0] }, ['dir coll', $file];
      } else {
        my ($ext) = $file =~ m{[.]([^.]+)\Z}mxs ? $1 : q();
        $ext = exists $types{$ext} ? $types{$ext} : 'unknown';
        push @{ $files[1] }, ["file ext_$ext", $file];
      }
    }
    closedir $bin;
    return q() if $total == 0;
    my $return = '<ul class="jft" style="display:none">';

    # print Folders
    foreach my $file (
      map {
        sort { $a->[1] cmp $b->[1] } @{$_}
      } @files
      ) {
      next unless -e "$full_dir$file->[1]";
      $return .= sprintf qq(\n  <li class="%s"><a href="#" rel="%s">%s</a></li>),
        $file->[0], encode_entities("$dir$file->[1]"), encode_entities( $file->[1] );
    }
    $return .= "\n</ul>\n";
    $self->print($return);
  } else {
    ## We have a file...
    return $self->forbidden unless substr( $full_dir, 0, length $root ) eq $root;
    my (
      $st_dev,$st_ino,$st_mode,$st_nlink,$st_uid,
      $st_gid,$st_rdev,$st_size,$st_atime,$st_mtime,
      $st_ctime,$st_blksize,$st_blocks ) = stat $full_dir;

    if( -d $full_dir ) {
      my $two_col_left = $self->twocol
        ->add_entry( 'File name',      q(/) . encode_entities($dir)   )
        ->add_entry( 'File type',      'Directory' );

      my $two_col_right = $self->twocol
        ->add_entry( 'Last modified',  time2str( $TIME_FMT, $st_mtime ) );

      $self->printf(q(<div class="col1">%s</div><div class="col2" style="height:150px;overflow:auto">%s</div>),
        $two_col_left->render, $two_col_right->render );
      return $self->ok;
    }

    my ($ext) = $dir =~ m{[.]([^.]+)\Z}mxs ? $1 : q();
    $ext = exists $types{$ext} ? $types{$ext} : 'unknown';

    ## Get author information so we can set it!
    ## no critic (LongChainsOfMethodCalls)
    my $two_col_left = $self->twocol
      ->add_entry( 'File name',      q(/) . encode_entities($dir)   )
      ->add_entry( 'File type',      $types_desc{$ext}              )
      ->add_entry( 'File size',      sprintf '%d bytes', -s $full_dir    )
      ->add_entry( 'Last modified',  time2str( $TIME_FMT, $st_mtime ) );
    ## use critic
    my $two_col_right = $self->twocol;

    my @actions;
    if ( $ext eq 'img' ) {
      $two_col_right->add_entry( 'Image dimensions', sprintf ' (%d x %d)', imgsize($full_dir) );
    } elsif ( $ext eq 'html' ) {
      if( open my $fh, '<', $full_dir ) {
        local $INPUT_RECORD_SEPARATOR = undef;
        my $x = <$fh>;
        close $fh; ##no critic (CheckedSyscalls CheckedClose)
        if ( $x =~ m{<head.*?>(.*?)</head>}mxs ) {
          (my $head = $1 ) =~ s{<%.*?%>}{}mxsg;
          my $head_parser = HTML::HeadParser->new();
          my $head_info   = $head_parser->parse($head);
          ## no critic (DeepNests)
          if( $head_info ) {
            my $t           = $head_info->header('Title');
            $two_col_right->add_entry( 'Title', $t ) if $t;
            foreach (qw(Author Keywords Description)) {
              my $tvar = $head_info->header("X-Meta-$_");
              $two_col_right->add_entry( $_, $tvar ) if $tvar;
            }
          }
          ## use critic
        }
        push @actions, qq(<a href="/action/Raw/$dir?format=html" target="pg">Source</a>),
                       qq(<a href="/action/Developer_Edit/$dir" target="pg">Edit</a>);
      }
    }

    $two_col_left->add_entry( 'Actions', join q( ), @actions ) if @actions;
    $self->printf(q(<div class="col1">%s</div><div class="col2" style="height:150px;overflow:auto">%s</div>),
      $two_col_left->render, $two_col_right->render );
  }
  return $self->ok;
}
##use critic (ExcessComplexity)

1;
