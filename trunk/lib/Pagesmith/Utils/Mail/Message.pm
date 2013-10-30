package Pagesmith::Utils::Mail::Message;

## Base class to add common functionality!
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

use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use Encode qw();
use Const::Fast qw(const);
use Mail::Mailer;

const my $COLUMNS         => 72;
const my %USER_TYPES      => map { (uc $_,$_) } qw(Bcc Cc From To Reply-To);
const my %PRIORITIES      => qw( 1 Highest 2 High 3 Normal 4 Low 5 Lowest );
const my %PRIORITY_MAP    => map { uc $_ } reverse %PRIORITIES;
const my $NORMAL_PRIORITY => $PRIORITY_MAP{ 'NORMAL' };
const my $BOUNDARY_LENGTH => 12;
const my $LINE            => q(-) x $COLUMNS;

use Text::MultiMarkdown;
use List::MoreUtils qw(any);
use Pagesmith::Core qw(safe_md5);
use Pagesmith::ConfigHash qw(template_dir);
use Pagesmith::Utils::Curl::Fetcher;
use Pagesmith::Utils::Mail::Person;
use Pagesmith::Utils::Mail::File;
use Pagesmith::Utils::Wrap;

use base qw(Pagesmith::Root);

sub new {
  my $class = shift;
  my $self = {
    'send_method'     => q(mail),
    'mime'            => 1,       ## Default it to use MIME encoding!
    'files'           => [],
    'images'          => {},
    'styles'          => {},
    'style_counter'   => 0,
    'subs'            => {},
    'email_addresses' => {},
    'headers'         => {'X-Application' => ["Pagesmith/Mail-$VERSION"]},
    'body_text'       => [],
    'body_html'       => [],
    'wrapper'         => undef,
  };
  bless $self, $class;
  return $self;
}

sub wrapper {
  my $self = shift;
  return $self->{'wrapper'} ||= Pagesmith::Utils::Wrap->new;
}
sub images {
  my $self = shift;
  return values %{$self->{'images'}||{}};
}

sub files {
  my $self = shift;
  return @{$self->{'files'}||[]};
}

sub add_substitution {
  my( $self, $key, $value ) = @_;
  $self->{'subs'}{$key} = $value;
  return $self;
}

sub set_subject {
  my( $self, $value ) = @_;
  $self->{'subject'} = $value;
  return $self;
}

sub subject {
  my $self = shift;
  return $self->{'subject'};
}

sub set_priority {
  my( $self, $value ) = @_;
  $value ||= $NORMAL_PRIORITY;
  unless( $value =~ m{\A\d\Z}mxs ) {
    my $k = uc $value;
    $value = exists $PRIORITY_MAP{ $k } ? $PRIORITY_MAP{ $k } : $NORMAL_PRIORITY;
  }
  $self->{'priority'} = $value;
  return $self;
}

sub priority {
  my $self = shift;
  return $self->{'priority'};
}

sub request_read_receipt {
  my $self = shift;
  $self->{'read_receipt'} = 1;
  return $self;
}

sub no_read_receipt {
  my $self = shift;
  $self->{'read_receipt'} = 0;
  return $self;
}

sub read_receipt {
  my $self = shift;
  return $self->{'read_receipt'};
}

sub format_plain {
  my $self = shift;
  $self->{'mime'} = 0;
  return $self;
}

sub format_mime {
  my $self = shift;
  $self->{'mime'}       = 1;
  $self->{'boundary'} ||= '==Multipart_Boundary_'.$self->safe_uuid;
  return $self;
}

sub boundary {
  my $self = shift;
  return $self->{'boundary'};
}

sub is_mime {
  my $self = shift;
  return $self->{'mime'};
}

sub send_method {
  my $self = shift;
  return $self->{'send_method'};
}

sub method_debug {
  my $self = shift;
  $self->{'send_method'} = 'debug';
  return $self;
}

sub method_debug_html {
  my $self = shift;
  $self->{'send_method'} = 'debug_html';
  return $self;
}

sub method_email {
  my $self = shift;
  $self->{'send_method'} = 'mail';
  return $self;
}

sub method_queue {
  my($self,$queue) = @_;
  $self->{'queue'}       = $queue;
  $self->{'send_method'} = 'queue';
  return $self;
}

sub clear_content {
  my $self = shift;
  $self->{'body_text'} = [];
  $self->{'body_html'} = [];
  return $self;
}

sub set_style {
  my($self,$k,$v) = @_;
  $v =~ s{;\s*$}{}mxsg;
  $v =~ s{([:;])\s+}{$1}mxsg;

  push @{$self->{'styles'}{$k}},[$v,$self->{'style_counter'}++];
  return $self;
}

sub set_header {
  my($self,$k,$v, $flag) = @_;
  $self->{'headers'}{$k} = [];
  return $self->add_header($k,$v, $flag);
}

sub add_header {
  my($self,$k,$v, $flag) = @_;
  push @{$self->{'headers'}{$k}},
    $flag ? $v : Encode::encode( 'MIME-Header', $v);
  return $self;
}

sub address_headers {
  my $self = shift;

  foreach my $type ( keys %{$self->{'email_addresses'}} ) {
    next if $type eq 'TO';
    $self->add_header( $USER_TYPES{$type}, $self->address( $self->{'email_addresses'}{$type} ), 1 );
  }
  return $self;
}

sub address {
  my( $self, $people ) = @_;
  return join q(, ), map { $_->format_email } @{$people};
}

sub style_attr {
  my ( $self, @tags ) = @_;
  my @styles;
  foreach my $tag ( @tags ) {
    push @styles, map {$_->[0]}
                  sort { $a->[1] <=> $b->[1] }
                  @{$self->{'styles'}{$tag}||[]};
  }
  return unless @styles;
  return sprintf ' style="%s"', join q(; ), @styles;
}

sub add_heading {
  my( $self, $text, $options ) = @_;
  $self->add_text($LINE,"\n",$text,"\n",$LINE,"\n\n");
  my $level = exists $options->{'main'} ? 'h2' : 'h3';
  $self->add_html( sprintf "<$level%s>\n%s\n</$level>",
    $self->style_attr( $level ), $self->encode( $text ),
  );
  return $self;
}

sub add_text {
  my( $self, @txt ) = @_;
  push @{$self->{'body_text'}}, @txt;
  return $self;
}

sub body_text {
  my $self = shift;
  return join q(), @{$self->{'body_text'}};
}

sub add_html {
  my( $self, @html ) = @_;
  push @{$self->{'body_html'}}, @html;
  return $self;
}

sub add_html_chunk {
  my( $self, $html ) = @_;
  $self->add_html( $self->modify_html( $html ) );
  return $self;
}
sub body_html {
  my $self = shift;
  return join q(), @{$self->{'body_html'}};
}

sub add_list {
  my( $self, $head, $list, $options ) = @_;
  $self->add_block( $head, { 'type' => 'p', 'class' => $options->{'head_class'}||q()} );
  my $numbered = $options->{'type'} && $options->{'type'} eq 'number';
  $self->add_html( $numbered ? '<ol>' : '<ul>' );
  my $counter = 1;
  foreach( @{$list} ) {
    $self->wrapper->set_headers(
      $numbered ? ( sprintf '%2d) ', $counter++ ) : q(  * ),
      q(    ),
    );
    $self->add_block( $_, {
      'type'  => 'li',
      'class' => $options->{'list_class'}||q(),
    } );
  }
  $self->wrapper->reset_headers;
  $self->add_html( $options->{'type'} && $options->{'type'} eq 'number' ? '</ol>' : '</ul>' );
  return $self;
}

sub add_markdown {
  my( $self, $text ) = @_;
  my $m    = Text::MultiMarkdown->new( 'heading_ids' => 0, 'img_ids' => 0 );
  my $html = $m->markdown( $text );

  $html =~ s{<h([123])(.*?</h)\1>}{'<h'.($1+1).$2.($1+1).'>'}mxseg;
  $html = "<p>$html</p>" unless $html =~ m{\A<}mxsg;
  return $self->add_text( $text )
              ->load_images_from_html(\$html)
              ->add_html( $self->modify_markdown_html($html) ); ## Need to do some post processing here!
}
sub add_block {
  my( $self, $text, $options ) = @_;
  $options = { 'type' => $options } unless ref $options;
  my $block_type = $options->{'type'}||'p';
  $self->add_text( $self->wrapper->wrap( $text ), "\n" );
  ## no critic (InterpolationOfMetachars)
  $self->add_html( sprintf '<%1$s%3$s>%2$s</%1$s>',
    $block_type,
    $self->format_html( $text ),
    $self->style_attr( $block_type, map { ".$_" } split m{\s+}mxs, $options->{'class'} ),
  );
  ## use critic
  return;
}

sub format_html {
  my( $self, $string ) = @_;
  $string = $self->encode( $string );
  $string =~ s{(\S+@\S+)}{<a href="mailto:$1">$1</a>}mxsg;
  $string =~ s{(https?://\S+)}{<a href="$1">$1</a>}mxsg;
  return $string;
}

## Loading images...
sub load_images_from_html {
  my( $self, $html ) = @_;
  my @parts = split m{(<img\s.*?src="[^"]+".*?/>|url[(][^)]+?[)])}mxs, ${$html};
  my @out;
  foreach (@parts) {
    if(m{\A(<img\s.*?src=")([^"]+)(".*?/>)\Z}mxs ||
       m{\A(url[(])([^)]+)([)])\Z}mxs) {
      my $im   = $self->add_image_from_url( $2 );
      push @out, $1.'cid:'.$im->cid.$3;
    } else {
      push @out, $_;
    }
  }
  ${$html} = join q(), @out;
  return $self;
}

sub add_image {
  my( $self, $file, $caption ) = @_;
  my $timg = $self->add_image_from_url( $file );
  if( $timg ) {
    $self->add_html(
      sprintf '<div style="text-align:center"><img src="cid:%s" style="width: %dpx; height: %dpx" />%s</div>',
        $timg->cid,
        $timg->width,
        $timg->height,
        $caption ? sprintf '<br />'.$self->encode( $caption ) : q(),
    );
  }
  return $self;
}

sub add_image_from_string {
  my ( $self, $key, $string ) = @_;
  unless( exists $self->{'images'}{$key} ) {
    my $file = $self->new_file;
    my $flag = $file->load_from_string( $key, $string );
    return unless $flag;
    $self->{'images'}{$key} = $file;
  }
  return $self->{'images'}{$key};
}

sub add_image_from_file {
  my ( $self, $key, $file_name ) = @_;
  unless( exists $self->{'images'}{$key} ) {
    my $file = $self->new_file;
    my $flag = $file->load_from_file( $key, $file_name );
    return unless $flag;
    $self->{'images'}{$key} = $file;
  }
  return $self->{'images'}{$key};
}

sub add_image_from_url {
  my( $self, $url, $mime_type ) = @_;
  my $key = "URL:$url";
  unless( exists $self->{'images'}{$key} ) {
    my $file = $self->new_file;
    my $flag = $file->load_from_url( $url, $mime_type );
    return unless $flag;
    $self->{'images'}{$key} = $file;
  }
  return $self->{'images'}{$key};
}

## Loading files...
sub new_file {
  my $self = shift;
  return Pagesmith::Utils::Mail::File->new;
}

sub add_file {
  my( $self, $file ) = @_;
  push @{$self->{'files'}}, $file;
  return $self;
}

sub add_file_from_string {
  my ( $self, $code, $string, $mime_type ) = @_;
  my $file = $self->new_file;
  my $flag = $file->load_from_string( $code, $string, $mime_type );
  return unless $flag;
  $self->add_file( $file );
  return $file;
}

sub add_file_from_file {
  my ( $self, $code, $file_name, $mime_type ) = @_;
  my $file = $self->new_file;
  my $flag = $file->load_from_string( $code, $file_name, $mime_type );
  return unless $flag;
  $self->add_file( $file );
  return $file;
}

sub add_file_from_url {
  my ( $self, $url, $mime_type ) = @_;
  my $file = $self->new_file;
  my $flag = $file->load_from_url( $url, $mime_type );
  return unless $flag;
  $self->add_file( $file );
  return $file;
}

sub add_email_name {
  my( $self, $type, $email, $name ) = @_;
  return $self->add_person( $type, Pagesmith::Utils::Mail::Person->new( $email, $name ) );
}

sub add_person {
  my( $self, $type, $person ) = @_;
  $type = uc $type;
  return $self unless exists $USER_TYPES{$type};
  push @{$self->{'email_addresses'}{$type}}, $person;
  return $self;
}

sub parse_css {
  my( $self, $html ) = @_;
  my @parts = split m{(<style[ ]type="text/css">.*?</style>)}mxs, ${$html};
  my @out;
  foreach my $sheet (@parts) {
    if( $sheet =~ m{<style[ ]type="text/css">(.*?)</style>}mxs ) {
      my @blocks = split m{[{](.*?)[}]}mxs, $1;
      while( @blocks > 1 ) {
        my $k = $self->trim(shift @blocks);
        my $v = $self->trim(shift @blocks);
        $self->set_style( $_, $v ) foreach split m{,\s+}mxs, $k;
      }
    } else {
      push @out, $sheet;
      next;
    }
  }
  ${$html} = join q(), @out;
  return $self;
}

sub get_templates {
  my( $self, $name ) = @_;
  $self->get_template_text( $name.'.txt' )
       ->get_template_html( $name.'.html' );
  return $self;
}

sub template_text {
  my $self = shift;
  return $self->{'template_text'};
}

sub get_template_text {
  my( $self, $name ) = @_;
  ## Get template path! and look in mail sub-folder!
  my $file = sprintf '%s/mail/%s', template_dir(), $name;
  if( -e $file && ! -d $file ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $fh;
    ## no critic (BriefOpen) - not sure why this is required!
    if( open $fh, '<', $file ) {
      $self->{'template_text'} = <$fh>;
      close $fh; ##no critic (CheckedSyscalls CheckedClose)
      return $self;
    }
    ## use critic
  }
  $self->{'template_text'} = '[[content]]';
  return $self;
}

sub template_html {
  my $self = shift;
  return $self->{'template_html'};
}

sub get_template_html {
  my( $self, $name ) = @_;
  my $file = sprintf '%s/mail/%s', template_dir(), $name;
  if( -e $file && ! -d $file ) {
    local $INPUT_RECORD_SEPARATOR = undef;
    my $fh;
    if( open $fh, '<', $file ) {
      my $html = <$fh>;
      close $fh; ##no critic (CheckedSyscalls CheckedClose)
      $self->load_images_from_html( \$html );
      $self->parse_css( \$html );
      $self->{'template_html'} = $html;
      return $self;
    }
  }
  $self->{'template_html'} = q();
  return $self;
}

sub backup_headers {
  my $self = shift;
  $self->{'backup_headers'} = $self->{'headers'};
  $self->{'headers'} = {};
  foreach my $k ( keys %{$self->{'backup_headers'}} ) {
    $self->{'headers'}{$k} = [ @{$self->{'backup_headers'}{$k}||[]} ];
  }
  return $self;
}

sub restore_headers {
  my $self = shift;
  $self->{'headers'} = $self->{'backup_headers'};
  return $self;
}

sub send_email {
  my( $self, $separate ) = @_;
  $self->backup_headers
       ->address_headers;

  if( $self->is_mime ) {
    $self->add_header( 'MIME-Version', '1.0' );
  }
  $self->add_header( 'X-Priority', sprintf '%d (%s)', $self->priority, $PRIORITIES{$self->priority} )
    if $self->priority;
  if( $self->read_receipt ) {
    my $from = exists $self->{'email_addresses'}{'REPLY-TO'} ? $self->{'email_addresses'}{'REPLY-TO'}[0]
             : exists $self->{'email_addresses'}{'FROM'}     ? $self->{'email_addresses'}{'FROM'}[0]
             : undef
             ;
    if( $from ) {
      $self->add_header( $_, $from->format_email ) foreach qw(Disposition-Notification-To X-Confirm-Reading-To Return-Receipt-To);
    }
  }
  my $output = q();
  if( $separate ) {
    foreach my $person ( @{$self->{'email_addresses'}{'TO'}} ) {
      $self->add_substitution( 'to_name'  => $person->name );
      $self->add_substitution( 'to_email' => $person->email );
      $self->set_header( 'Subject', $self->subject_line );
      $output .= $self->email( $person->format_email );
    }
  } else {
    my $person = $self->{'email_addresses'}{'TO'}[0];
    $self->add_substitution( 'to_name'  => $person->name );
    $self->add_substitution( 'to_email' => $person->email );
    $self->add_header( 'Subject', $self->subject_line );
    $output .= $self->email( $self->address( $self->{'email_addresses'}{'TO'} ) );
  }
  $self->restore_headers;
  return $output;
}

sub formatted_headers {
  my $self = shift;
  return join q(), map {
    sprintf "$_: %s\r\n", join q(, ), @{$self->{'headers'}{$_}}
  } sort keys %{$self->{'headers'}};
}

sub headers {
  my $self = shift;
  return $self->{'headers'};
}

sub email {
  my( $self, $to ) = @_;
  my $content = $self->content;
  $self->set_header( 'To', $to );
  return sprintf "<pre>%s\r\n\r\n%s</pre>",
    $self->encode( $self->formatted_headers ),
    $self->encode( $content ) if $self->send_method eq 'debug_html';
  return sprintf "%s\r\n\r\n%s",
    $self->formatted_headers,
    $content if $self->send_method eq 'debug';
  return $self->queue->push( $to, $self->headers, $content ) if $self->send_method eq 'queue';

  my $mailer = Mail::Mailer->new;
  return unless $mailer;
  $mailer->open( $self->headers );
  binmode $mailer,':utf8'; ## no critic (EncodingWithUTF8Layer)
  print {$mailer} $content; ## no critic (CheckedSysCalls);
  $mailer->close;
  return "SENT OK\n";
}

sub subject_line {
  my $self = shift;
  return $self->substitute( $self->subject );
}

sub content {
  my $self = shift;

  ## Bomb out early if not mime..!
  return $self->add_header( 'Content-type', 'text/plain; charset=UTF-8' )->content_plain
    unless $self->is_mime && $self->template_html;
  my $b = $self->boundary;
  ## Get HTML mail content!
## no critic (ImplicitNewlines InterpolationOfMetachars)
  my $html_mail_content = 'Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: 8bit

'.$self->content_html;
  my $plain_mail_content = 'Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit

'.$self->content_plain;

  if( $self->images ) {
    $html_mail_content = sprintf 'Content-Type: multipart/related; boundary="%1$s_r"

--%1$s_r
%2$s
%3$s
--%1$s_r--', $b, $html_mail_content,
    join q(), map { sprintf "--%s_r\n%s\r\n", $b, $_->render('image') } $self->images;
  }
  if( $self->files ) {
    $self->add_header( 'Content-type', qq(multipart/mixed; boundary="${b}_m") );
    return sprintf 'This is a multi-part message in MIME format.
--%1$s_m
Content-Type: multipart/alternative; boundary="%1$s_a"

--%1$s_a
%2$s
--%1$s_a
%3$s
--%1$s_a--
%4$s--%1$s_m--', $b, $plain_mail_content, $html_mail_content,
      join q(), map { sprintf "--%s_m\r\n%s", $b, $_->render('attach') } $self->files;
  }
  $self->add_header( 'Content-type', qq(multipart/alternative; boundary="${b}_a") );
  return sprintf 'This is a multi-part message in MIME format.
--%1$s_a
%2$s
--%1$s_a
%3$s
--%1$s_a--', $b, $plain_mail_content, $html_mail_content;
## use critic
}

sub substitute {
  my( $self, $string ) = @_;
  $string =~ s{\[\[(\w+)\]\]}{$self->{'subs'}{$1}||"**$1**"}mxseg;
  return $string;
}

sub content_html {
  my $self = shift;
  my $body = $self->substitute( $self->body_html );
  ( my $html = $self->template_html ) =~ s{\[\[content\]\]}{$body}mxs;
  return $html;
}

sub content_plain {
  my $self = shift;
  my $body = $self->substitute( $self->body_text );
  ( my $text = $self->template_text ) =~ s{\[\[content\]\]}{$body}mxs;
  $text =~ s{(?<!\r)\n}{\r\n}msxg;
  return $text;
}

sub get_style_groups {
  my( $self, $flag ) = @_;
  return $self->{'style_groups'} if exists $self->{'style_groups'} && ! $flag;

  $self->{'style_groups'} = $self->{'style_groups'} ||= [
    sort { $a->[2] cmp $b->[2] }
  ##   { styles for group, [reversed tags - closest first], specificity "{####}{####}{####}" }
## Compute specificity...
    map  { [
      $self->{'styles'}{$_->[0]},
      [reverse @{$_->[1]}],
      sprintf '%04d%04d%04d',
        ( scalar grep { m{[#]}mxs  } @{$_->[1]} ),
        ( scalar grep { m{[.]}mxs  } @{$_->[1]} ),
        ( scalar grep { m{\A\w}mxs } @{$_->[1]} ),
    ] }
    map  { [$_, [m{(\S+)}mxsg]] }
    keys %{$self->{'styles'}},
  ];
  foreach my $sg ( @{$self->{'style_groups'}} ) {
    my @tags = @{$sg->[1]};
    $sg->[1] = [];
    foreach my $tag (@tags) {
      my @parts = split m{([.#])}mxs,$tag;
      my $href = {'classes'=>[],};
      my $type = 'name';
      foreach( @parts ) {
        if( $_ eq q(.) ) {
          $type = 'class';
        } elsif( $_ eq q(#)) {
          $type = 'id';
        } elsif( $type eq 'class' ) {
          push @{$href->{'classes'}}, $_;
        } else {
          $href->{$type} = $_;
        }
      }
      push @{$sg->[1]},$href;
    }
  }
  return $self->{'style_groups'};
}

## no critic (ExcessComplexity)
sub apply_styles {
  my( $self, $html_in, $style_groups ) = @_;
  my @html_out;
  my @tags;
  my @in = split m{(<.*?>)}mxs, $html_in;
  foreach my $chunk (@in) {
    unless($chunk =~ m{\A<}mxs) { ## Not a tag - so we just push the contents...
      push @html_out, $chunk;
      next;
    }
    if($chunk =~ m{\A</}mxs) {
      ## This is closing tag so again we push the content, but also remove tag
      ## from list of active tags
      shift @tags;
      push @html_out, $chunk;
      next;
    }
    if($chunk =~ m{\A<(\w+)(\s*.*?)>\Z}mxs ) {
      my( $tag_name, $attributes ) = ($1,$2);
      my %styles;
      ## Now we have to get classes list...
      ## Get any ids and classes...
      my @Q = $attributes =~ m{(\w+)=(['"])(.*?)\2}mxsg;
      my %attributes;
      while( $_ = shift @Q ) {
        shift @Q;
        $attributes{$_} = shift @Q;
      }
      unshift @tags, { 'name'    => $tag_name,
                       'id'      => $attributes{'id'}||q(),
                       'classes' => { map { ($_=>1) } split m{\s+}mxs, $attributes{'class'}||q() },
                     };
      foreach my $sg (@{$style_groups}) {
        ## sg = [ styles for group, reversed tags, specificity string... ]
        my @css_tags = @{$sg->[1]};
        ## Check to see if tag matches...
        my $inital_match = 1;
        next if $css_tags[0]{'name'} && $css_tags[0]{'name'} ne $tags[0]{'name'}; ## Tag name doesn't match!
        next if $css_tags[0]{'id'}   && $css_tags[0]{'id'}   ne $tags[0]{'id'};   ## Tag ID   doesn't match!
        next if @{$css_tags[0]{'classes'}} &&
          any { !exists $tags[0]{'classes'}{$_} } @{$css_tags[0]{'classes'}};    ## Classes don't match!
        my @this_tags = @tags;
        shift @this_tags;
        shift @css_tags;
        while ( @this_tags && @css_tags) {
          if($css_tags[0]{'name'} eq q(>)) {
            shift @css_tags;
            last if $css_tags[0]{'name'} && $css_tags[0]{'name'} ne $this_tags[0]{'name'}; ## Tag name doesn't match!
            last if $css_tags[0]{'id'}   && $css_tags[0]{'id'}   ne $this_tags[0]{'id'};   ## Tag ID   doesn't match!
            last if @{$css_tags[0]{'classes'}} &&
              any { !exists $this_tags[0]{'classes'}{$_} } @{$css_tags[0]{'classes'}};    ## Classes don't match!
            ## last if $css_tags[0] ne $this_tags[0]{'name'}; ## Not a match - required!
            shift @css_tags;
            shift @this_tags;
          } else {
            my $t_tag = shift @this_tags;
            next if $css_tags[0]{'name'} && $css_tags[0]{'name'} ne $t_tag->{'name'}; ## Tag name doesn't match!
            next if $css_tags[0]{'id'}   && $css_tags[0]{'id'}   ne $t_tag->{'id'};   ## Tag ID   doesn't match!
            next if @{$css_tags[0]{'classes'}} &&
              any { !exists $t_tag->{'classes'}{$_} } @{$css_tags[0]{'classes'}};    ## Classes don't match!
            shift @css_tags;
          }
        }
        next if @css_tags;
        push @{$styles{$sg->[2]}}, @{$sg->[0]};
      }
      if( keys %styles ) {
        $attributes{'style'} =
          $self->encode( join q(; ),
            map {
              map { $_->[0] } sort { $a->[1] <=> $b->[1] } @{$styles{$_}}
            } sort keys %styles ).
          (exists $attributes{'style'} ? "; $attributes{'style'}" : q());
      }
      push @html_out, q(<),
        $tag_name, map { qq( $_="$attributes{$_}") } sort keys %attributes;
      push @html_out, q(>);
      shift @tags if $chunk =~ m{/>\Z}mxs; ## Self closing... so remove from tag list!
    }
  }
  return join q(),@html_out;

}
## use critic

sub modify_html {
  my ( $self, $html ) = @_;
  ## We need to open each tag in turn and deal with it...
  return $self->apply_styles( $html, $self->get_style_groups );
}

sub modify_markdown_html {
  my ( $self, $html ) = @_;
  ## We need to open each tag in turn and deal with it...
  my @style_groups = grep { $_->[2] =~ m{\A00000000}mxs } @{$self->get_style_groups};
  return $self->apply_styles( $html, \@style_groups );
}

1;
