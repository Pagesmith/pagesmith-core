package Pagesmith::Utils::CodeWriter::Component;

## Package to write packages etc!

## Author         : James Smith <js5>
## Maintainer     : James Smith <js5>
## Created        : Mon, 11 Feb 2013
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');

use base qw(Pagesmith::Utils::CodeWriter);

sub base_class {
  my $self = shift;
  my $filename = sprintf '%s/Component%s.pm',$self->base_path,$self->ns_path;

## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $perl = sprintf q(package Pagesmith::Component::%1$s;

## Base class for components in %1$s namespace
%2$s
use base qw(Pagesmith::Component Pagesmith::Support::%1$s);

1;

__END__
),
    $self->namespace,    ## %1$
    $self->boilerplate,  ## %2$
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

sub admin {
  my ($self,$type) = @_;
  my $filename = sprintf '%s/Component%s/Admin/%s.pm',$self->base_path,$self->ns_path, $self->fp( $type );

## no critic (InterpolationOfMetachars ImplicitNewlines)
#@raw
  my $add_link = sprintf '/form/%s_Admin_%s', $self->ns_comp, $self->fp( $type );
  my $perl = sprintf q(package Pagesmith::Component::%1$s::Admin::%2$s;

## Admininstration component for objects of type %2$s
## in namespace %1$s
%3$s
use base qw(Pagesmith::Component::%1$s);

sub define_options {
#@params (self)
#@return (hashref option defn)+
## Returns an array of hashrefs defining the options the component takes
  my $self = shift;
  return (
    $self->ajax_option,
  );
}

sub usage {
#@params (self)
#@return (hashref)
## Returns a hashref of documentation of parameters and what the component does!
  my $self = shift;
  return {
    'parameters'  => 'NONE',
    'description' => 'Admin component for %2$s objects in %1$s',
    'notes'       => [],
  };
}

sub ajax {
#@params (self)
#@return (boolean)
## returns true if the component content generation is to be "delayed" and included via AJAX
  my $self = shift;
  return $self->default_ajax;
}

sub execute {
#@params (self)
#@return (html)
## returns an HTML table displaying contents of object along with links to the edit forms...
  my $self = shift;
%4$s
  return $table->render.
    sprintf '<p><a href="%5$s">Add</a></p>';
}

1;

__END__
),
    $self->namespace,      # %1$s
    $type,                 # %2$s
    $self->boilerplate,    # %3$s
    $self->admin_table( $type ), # %4$s
    $add_link              # %5$s
    ;
#@endraw
## use critic
  return $self->write_file( $filename, $perl );
}

1;

