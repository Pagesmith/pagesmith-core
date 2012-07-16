package Pagesmith::Component::Audio;

## Component to display YouTube videos
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

use base qw(Pagesmith::Component::File);

use HTML::Entities qw(encode_entities);

sub _cache_key {
  my $self = shift;
  return $self->checksum_parameters();
}

sub execute {
  my $self = shift;

  my $trans_markup = q();
  my $transcript = $self->option('transcript')||q();
  if( $transcript ) {
    my $err = $self->check_file($transcript);
    unless( $err ) {
      local $INPUT_RECORD_SEPARATOR = undef;
      my $html = q();
      if( open my $fh, '<', $self->filename ) {
        $html = <$fh>;
        close $fh; ## no critic (CheckedSyscalls CheckedClose)
      }
      if( $html ) {
        $html =~ s{\A\xEF\xBB\xBF}{}mxs; ## Nasty code - we need to remove the BOM if there is one!
        $trans_markup = sprintf
          q(<div class="collapsible collapsed transcript"><h4 class="keep">Transcript</h4><div class="clear coll yscroll">%s</div></div>),
          $html;
      }
    }
  }
  my $URL = $self->next_par;
  my $title = join q( ), $self->pars;
  return sprintf '<div class="panel project audio"><h3>%s</h3><a href="%s" class="mp3">PLAY</a>%s</div>',
    $self->encode( $title ), $self->encode( $URL ), $trans_markup;
}
1;

__END__

