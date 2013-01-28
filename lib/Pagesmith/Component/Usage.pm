package Pagesmith::Component::Usage;

## Return last modified date of file...
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

use base qw(Pagesmith::Component);

use Date::Format qw(time2str);

sub define_options {
  my $self = shift;
  return (
    { 'code' => 'zone', 'defn' => '=s',
      'description' => 'Time zone' },
    { 'code' => 'format','defn' => '=s', 'default'     => '%a, %d %b %Y %H:%M %Z',
      'description' => 'Standard time2str date format' },
  );
}

sub usage {
  my $self = shift;
  return {
    'parameters'  => q({name=s}),
    'description' => 'Display brief usage for module',
    'notes'       => [
      '{name} name of module',
    ],
  };
}

sub expand_usage {
  my( $self, $comp_obj ) = @_;
  my @options    = $comp_obj->can( 'define_options' ) ? $comp_obj->define_options : ();
  my $usage_hash = $comp_obj->can( 'usage' )          ? $comp_obj->usage : {};
  ## no critic (ImplicitNewlines)
  my $html = sprintf '
  <p>%s</p>
  <h4>Parameters</h4>
  <ul>
    <li>%s</li>
  </ul>
  <h4>Options</h4>
    %s
  <h4>Notes</h4>
  %s
  ',
    $self->encode( $usage_hash->{'description'} || 'No description' ),
    $self->encode( exists $usage_hash->{'parameters'} ?
      ( $usage_hash->{'parameters'} || 'NONE' ) : 'Not specified' ),
    $self->display_options( \@options ),
    $self->display_notes( $usage_hash->{'notes'}||[] );
  ## use critic;
  return $html;
}

sub display_options {
  my( $self, $options_array ) = @_;
  return '<p>NONE</p>' unless @{$options_array};
  return $self->table
    ->add_columns(
      { 'key' => 'code',        'label' => 'Name',            },
      { 'key' => 'defn',        'label' => 'Definition',      },
      { 'key' => 'default',     'label' => 'Default value',   },
      { 'key' => 'description', 'label' => 'Description',     },
      { 'key' => 'interleave',  'label' => 'Interleave?',     },
    )
    ->add_data( @{$options_array} )
    ->render;
}

sub display_notes {
  my( $self, $notes_array ) = @_;
  return q(<p>-</p>) unless @{$notes_array};
  return sprintf '<ul><li>%s</li></ul>',
    join q(</li><li>),
      map { $self->encode( $_ ) } @{$notes_array};
}

sub execute {
  my $self = shift;
  my $component = $self->safe_module_name( $self->next_par );
  my $module = "Pagesmith::Component::$component";
  if( $self->dynamic_use($module) ) {
    my $comp_obj = $module->new( $self->page );
    return sprintf '<h3>Component: %s</h3>%s',
      $self->encode( $component ),
      $self->expand_usage( $comp_obj );
  }
  return '<h3>Unknown component</h3>';
}
1;

__END__

h3. Syntax

<%

%>

h3. Purpose

h3. Options

h3. Notes

h3. See also

h3. Examples

h3. Developer notes

