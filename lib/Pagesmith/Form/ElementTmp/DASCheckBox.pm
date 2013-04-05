package Pagesmith::Form::ElementTmp::DASCheckBox;

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

use Const::Fast qw(const);
const my $DAS_DESC_WIDTH => 120;

use base qw( Pagesmith::Form::Element::CheckBox);

use HTML::Entities qw(encode_entities);

sub new {
  my( $class, %params ) = @_;
  my $das = $params{'das'};
  $params{'long_label'} ||= 1;
  $params{'name'}       ||= 'logic_name';
  $params{'value'}      ||= $das->logic_name;
  $params{'label'}      ||= $das->label;
  $params{'bg'}         ||= 'bg1';
  my $self = $class->SUPER::new( %params );
  $self->{'checked'}  = $params{'checked'};
  $self->{'disabled'} = $params{'disabled'};
  $self->_short_das_desc( $das);
  return $self;
}

sub _short_das_desc {
  my ($self, $source ) = @_;
  my $desc = $source->description;
  if (length $desc > $DAS_DESC_WIDTH) {
    $self->{'comment'} = $desc;
    $desc = substr $desc, 0, $DAS_DESC_WIDTH;
    $desc =~ s{\s[[:alnum:]]+\Z}{ \.\.\.}mxs; # replace final space with " ..."
  }
  $self->{'notes'} = encode_entities($desc);
  $self->{'notes'} .= sprintf ' [<a target="_new" href="%s" rel="external">Homepage</a>]', $source->homepage if $source->homepage;
  return;
}

sub render {
  my $self   = shift;

  my $notes = $self->notes;
  $notes .= sprintf ' (<span title="%s">Mouseover&#160;for&#160;full&#160;text</span>)',
    encode_entities($self->comment) if $self->comment;

  my $label = $self->{'raw'} ? $self->label : '<strong>'.encode_entities( $self->label ).'</strong>';
  $label .= '<br />'.$notes if $notes;
  ##no critic (ImplicitNewlines)
  return sprintf '<tr class="%s">
<td style="width:5%">
<input type="checkbox" name="%s" id="%s" value="%s" class="input-checkbox"%s%s/>
</td>
<td style="width:90%">%s</td>
</tr>',
      $self->bg,
      encode_entities( $self->name ),
      encode_entities( $self->id ),
      $self->value || 'yes',
      $self->checked ? ' checked="checked" ' : q(),
      $self->disabled ? ' disabled="disabled" ' : q(),
      $label,
  ;
  ##use critic (ImplicitNewlines)
}

1;
