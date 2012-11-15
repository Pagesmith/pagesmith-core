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

## no critic (ExcessComplexity)
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

  my @els = $form->all_input_elements;
  my $extra_html = q();

  if( exists $conf->{'column_sets'} ) {
    ( my $base = ref $self ) =~ s{\APagesmith::Action::}{}mxs;
    my $column_set = $self->next_path_info || 'default';
    $column_set = 'default' unless exists $conf->{'column_sets'}{$column_set};
    if( @{$conf->{'column_sets'}{$column_set}} ) {
      my %cols_to_show = map { ($_ => 1) } @{$conf->{'column_sets'}{$column_set}};
      @els = grep { exists $cols_to_show{$_->code} } @els;
      $extra_html = sprintf '<ul>%s</ul>',
        join q(), map {(sprintf '<li><a href="/action/%s/%s">%s</a>',$base,$_,$_)} sort keys %{$conf->{'column_sets'}};
    }
  }

  my @columns;
  foreach( @els ) {
    my $method = 'get_'.$_->code;
       $method = 'date_'.$_->code if $_->isa('Pagesmith::Form::Element::DateTime');

    my $format = $_->isa('Pagesmith::Form::Element::Date')     ? 'date'
               : $_->isa('Pagesmith::Form::Element::Email')    ? 'email'
               :                                                 undef
               ;
    my $align  = $_->isa('Pagesmith::Form::Element::YesNo')    ? 'c'
               : $_->isa('Pagesmith::Form::Element::DateTime') ? 'c'
               :                                                 'l'
               ;
    push @columns, { 'key' => $method, 'label' => $_->hidden_caption || $_->caption || q(-),
      'format' => $format, 'align' => $align };
  }

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
      { 'key' => 'code', 'label' => 'Ref', 'align' => 'c', 'link' => $self->non_admin_base_url.'/form/-[[u:code]]' },
      @columns,
      { 'key' => 'created_at', 'label' => 'Registered at', 'format' => 'datetime' },
    )
    ->add_data( @{$form->adaptor->get_all( @{$conf->{'filter'}||[]} )} )
    ->render. $extra_html )->ok;
## use critic
}
## use critic

1;
