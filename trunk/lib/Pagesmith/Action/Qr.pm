package Pagesmith::Action::Qr;

## Handles external links (e.g. publmed links)
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
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);
use Const::Fast qw(const);
const my $ONE_DAY => 86_400;

use Pagesmith::Cache;
use Pagesmith::ConfigHash qw(get_config);
use Pagesmith::Adaptor::Qr;

sub run {
  my $self  = shift;
  return $self->no_content unless get_config( 'QrEnabled' );
  my $qr_url = get_config( 'QrURL' ) || $self->base_url.'/qr/';

  my $key   = $self->next_path_info;
  my $image = $key =~ s{[.]png\Z}{}mxs ? 1 : 0;

  unless( $image ) {
    my $qr_obj = Pagesmith::Adaptor::Qr->new()->get_by_code( $key );
    return $qr_obj && $qr_obj->url ? $self->redirect( $qr_obj->url ) : $self->no_content;
  }

  my $ch = Pagesmith::Cache->new( 'tmpfile', "qr|$key.png" );    ## Generate the image....
  my $img_content = $ch->get;

  unless( $img_content ) {
    my $tmp_filename = $self->tmp_filename('.png');
    my $return = system 'qrencode', '-m', '1', '-s', '2', '-l', 'Q', '-8', '-v', '3', '-o', $tmp_filename, $qr_url.$key;
    return $self->no_content if $return;
    $return = system 'optipng', '-o2', '-q', '-preserve', $tmp_filename;
    return $self->no_content unless open my $fh, '<', $tmp_filename;
    local $INPUT_RECORD_SEPARATOR = undef;
    $img_content = <$fh>;
    close $fh; ## no critic (RequireChecked)
    unlink $tmp_filename;
    $ch->set( $img_content );
  }

  return $self
    ->content_type( 'image/png' )
    ->set_last_modified( time - $ONE_DAY )
    ->set_expires_header
    ->set_length( length $img_content )
    ->print( $img_content )
    ->ok;
}

1;
