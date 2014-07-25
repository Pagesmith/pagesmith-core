package Pagesmith::Component::Audio;

#+----------------------------------------------------------------------
#| Copyright (c) 2012, 2013, 2014 Genome Research Ltd.
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

sub usage {
  ## no critic (ImplicitNewlines)
  return {
    'parameters'  => '{URL=s} {title=s+}',
    'description' => 'Includes a link to an audio file (mp3) along with an optional transcript (and description)',
    'notes'       => [],
    'see_also'    => { '/core/js/pagesmith/audio-mp3.js' =>
      'Script which converts the link to the audio file into an embeded
       audio control, either as a native HTML <audio> tag - using OGG
       format version of file or an embeded player for MP3 files' ,
    },
  };
  ## use critic
}

sub define_options {
  my $self = shift;
  return  (
    { 'code' => 'transcript', 'defn' => '=s', 'default' => q(), 'description' => 'Text of transcript of audio file' },
  );
}

sub my_cache_key {
  my $self = shift;
  return $self->checksum_parameters();
}

sub execute {
  my $self = shift;

  my $trans_markup = q();
  my $transcript = $self->option('transcript');
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

