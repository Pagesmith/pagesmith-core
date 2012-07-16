package Pagesmith::Action::GenericAdmin;

## Author         : nb5
## Maintainer     : nb5
## Created        : 2011-09-30
## Last commit by : $Author$
## Last modified  : $Date$
## Revision       : $Revision$
## Repository URL : $HeadURL$

use strict;
use warnings;
use utf8;

use version qw(qv); our $VERSION = qv('0.1.0');
use Readonly qw(Readonly);
use base qw(Pagesmith::Action);

Readonly my $DEFAULT_PAGE => 10;

sub configuration {
  return;
}

sub non_admin_base_url {
  my $self = shift;
  return $self->base_url;
}
sub run {
  my $self = shift;
  my $conf = $self->configuration;

  return $self->wrap( 'This must be subclassed', '<p>You must sub-class this object to manage a generic object</p>' ) unless $conf;
  return $self->login_required unless $self->user->logged_in;

  $self->set_navigation_path( exists $conf->{'navpath'} ? $conf->{'navpath'} : '/admin/registrations/' );
  if( exists $conf->{'users'} && ref $conf->{'users'} eq 'ARRAY' && @{$conf->{'users'}} ) {
    my %users;
    @users{@{$conf->{'users'}}} = ();
    return $self->no_permission  unless exists $users{$self->user->username};
  }

  my $form = $self->form( $conf->{'form_type'} );
  ## Really nasty - get the form object - and grab all it's input elements!
  my @columns = map { {
    'key'    => $_->code,
    'label'  => $_->hidden_caption || $_->caption,
    'format' => $_->isa( 'Pagesmith::Form::Element::Email' ) ? 'email' : undef,
    'align'  => $_->isa( 'Pagesmith::Form::Element::YesNo' ) ? 'c'     : 'l',
  } } $form->all_input_elements;

  ## no critic (LongChainsOfMethodCalls)
  return $self->wrap( $form->title, $self->table
    ->make_sortable
    ->make_scrollable
    ->set_summary( $form->title )
    ->set_filter
    ->add_classes(     qw(before narrow-sorted)             )
    ->set_export(     [qw(txt csv xls)]                     )
    ->set_pagination( [qw(10 25 50 100 all)], $DEFAULT_PAGE )
    ->add_columns(
      { 'key' => q(#) },
      { 'key' => 'code', 'label' => 'Booking ref', 'align' => 'c', 'link' => $self->non_admin_base_url.'/form/-[[u:code]]' },
      @columns,
      { 'key' => 'created_at', 'label' => 'Registered at', 'format' => 'datetime' },
    )
    ->add_data( @{$form->adaptor->get_all( @{$conf->{'filter'}||[]} )} )
    ->render )->ok;
## use critic
}

1;
