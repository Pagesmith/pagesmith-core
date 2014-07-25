package Pagesmith::MyForm::Blast;

#+----------------------------------------------------------------------
#| Copyright (c) 2011, 2012, 2013, 2014 Genome Research Ltd.
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

## Blast submission form set up...
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
use feature ':5.10';

use version qw(qv); our $VERSION = qv('0.1.0');

use Carp qw(croak);
use LWP::UserAgent;

use Const::Fast qw(const);
const my $MAXLEN => 100;

use base qw(Pagesmith::MyForm);

use Pagesmith::Config;
use Pagesmith::Utils::BlastSubmitter;

# THE ORDER OF METHOD CALLS.
# fetch_object is called first and stores a hash into an object from this class.
# initialize_form runs and sets up the form elements etc. Drop down options are empty so far.
# populate_object_values is then run which fills the drop down boxes with options and may add an info panel.
# on_confirmation is called on for when the submit button is pressed.
## no critic (LongChainsOfMethodCalls)
sub on_confirmation {
  my( $self, $stage ) = @_;
  return unless $stage->id eq 'check';

  my $args = {
    'jobname'        => $self->code,
    'query'          => $self->element('fasta')->value,
    'db'             => $self->element('database')->value,
    'prog'           => $self->element('program')->value,
    'num_alignments' => $self->element('num_alignments')->value,
  };

  given($self->element('program')->value){
    when ('blastn') {
      $self->create_blastn_args($args);
    }
    when ('blastp' || 'tblastn')  {
      $self->create_blastp_tblastn_args($args);
    }
    when ('blastx' || 'tblastx')  {
      $self->create_blastx_tblastx_args($args);
    }
  }
  my $submission_object = Pagesmith::Utils::BlastSubmitter->new($args);
  $submission_object->run;
  $self->add_attribute( 'job_id', $submission_object->job_id );
  return;
}

sub create_blastx_tblastx_args {
  my ($self, $args) = @_;
  my $prog = $self->element('program')->value;
  $args->{'evalue'}           = $self->element($prog . '_evalue')->value;
  $args->{'word_size'}        = $self->element($prog . '_word_size')->value;
  $args->{'gap_costs'}        = $self->element($prog . '_gap_costs')->value;
  $args->{'lcase_masking'}    = $self->element($prog . '_lcase_masking')->value;
  $args->{'soft_masking'}     = $self->element($prog . '_soft_masking')->value;
  $args->{'matrix'}           = $self->element($prog . '_matrix')->value;
  $args->{'seg'}              = $self->element($prog . '_seg')->value;
  $args->{'query_gencode'}    = $self->element($prog . '_query_gencode')->value;
  $args->{'strand'}           = $self->element($prog . '_strand')->value;
  return;
}

sub create_blastp_tblastn_args {
  my ($self, $args) = @_;
  my $prog = $self->element('program')->value;
  $args->{'evalue'}           = $self->element($prog . '_evalue')->value;
  $args->{'word_size'}        = $self->element($prog . '_word_size')->value;
  $args->{'gap_costs'}        = $self->element($prog . '_gap_costs')->value;
  $args->{'lcase_masking'}    = $self->element($prog . '_lcase_masking')->value;
  $args->{'soft_masking'}     = $self->element($prog . '_soft_masking')->value;
  $args->{'matrix'}           = $self->element($prog . '_matrix')->value;
  $args->{'comp_based_stats'} = $self->element($prog . '_comp_based_stats')->value;
  $args->{'seg'}              = $self->element($prog . '_seg')->value;
  return;
}

sub create_blastn_args {
  my ($self, $args) = @_;
  my $task = $self->element('task')->value;
  $args->{'task'}          = $task;
  $args->{'evalue'}        = $self->element($task . '_evalue')->value;
  $args->{'word_size'}     = $self->element($task . '_word_size')->value;
  $args->{'scores'}        = $self->element($task . '_scores')->value;
  $args->{'gap_costs'}     = $self->element($task . '_gap_costs')->value;
  $args->{'dust'}          = $self->element($task . '_dust')->value;
  $args->{'lcase_masking'} = $self->element($task . '_lcase_masking')->value;
  $args->{'soft_masking'}  = $self->element($task . '_soft_masking')->value;
  return;
}

# inherited from Pagesmith::Form and only returns $self therefore override.
sub populate_object_values {
  my $self = shift;
  ## Set and store species values...
  $self->element( 'species' )->set_obj_data( $self->object->{'species'} );

  ## Generate database drop down....

  my @dna_dbs  = grep { $_->[2] eq 'D' } @{$self->object->{'databases'}};
  my @prot_dbs = grep { $_->[2] ne 'D' } @{$self->object->{'databases'}};
  ## no critic (LongChainsOfMethodCalls)
  $self->element( 'database' )
    ->set_values( [ map { {
      'value'       => $_->[0],
      'name'        => $_->[1],
      'group'       => $_->[2] eq 'D' ? 'DNA databases' : 'Protein databases',
      'group_class' => $_->[2] eq 'D' ? 'dna' : 'pep',
    } } (@dna_dbs,@prot_dbs) ] )
    ->set_default_value( $self->object->{'default_db'} ? $self->object->{'default_db'} : $self->object->{'databases'}[0][0] )
    ->add_class( 'match_group_class', '_group_1' )
    ;

  ## Generate program drop down....
  my $program2name  = $self->pch->get('config','executables' );
  my @dna_programs  = grep { $program2name->{$_}->[1] eq 'D' } @{$self->object->{'executables'}};
  my @prot_programs = grep { $program2name->{$_}->[1] eq 'P' } @{$self->object->{'executables'}};

  $self->element( 'program' )
    ->set_values([ map {{
      'value'       => $_,
      'name'        => $program2name->{$_}[0],
      'group'       => $program2name->{$_}[1] eq 'D' ? 'for DNA databases' : 'for Protein databases',
      'group_class' => $program2name->{$_}[1] eq 'D' ? 'dna' : 'pep',
    }} (@dna_programs,@prot_programs) ])
    ->set_default_value( $self->object->{'default_program'} ? $self->object->{'default_program'} : $self->object->{'executables'}[0] )
    ->add_class( 'match_group_class', '_group_1' )
    ;
  ## use critic
  ## Add notes panel!
  if( $self->object->{'prologue'} ) {
    $self->add_stage( 'query_sequence' ); ## Not really add - but this just jumps to the query_sequence stage
      $self->add_section( 'query_sequence' );
        $self->add( 'Information', 'prologue' )->set_caption( $self->object->{'prologue'} );
  }
  if( $self->object->{'epilogue'} ) {
    $self->add_stage( 'query_sequence' ); ## Not really add - but this just jumps to the query_sequence stage
      $self->add_section( 'other_options' );
        $self->add( 'Information', 'epilogue' )->set_caption( $self->object->{'epilogue'} );
  }
  return $self;
}

sub default_id {
  my $self = shift;
  return 'a_fumigatus';
}

sub pch {
  my $self = shift;
  $self->{'pch'} ||= Pagesmith::Config->new({'file' => 'blast'});
  $self->{'pch'}->load(1);
  return $self->{'pch'};
}

# inherited from Pagesmith::Form and only returns $self therefore override.
sub fetch_object{
  my $self = shift;
  # object_id in this case is the species name from the url and hopefully matches a section in blast.yaml
  $self->{'object'} = $self->pch->get('species', lc $self->{'object_id'}) if $self->{'object_id'};
  $self->{'object'} = $self->get('species', $self->default_id) unless exists $self->{'object'};
  return $self->{'object'};
}

sub initialize_form { # inherited from Pagesmith::Form and only returns $self therefore override.
#@param (self)
  my $self = shift;

  ## no critic (LongChainsOfMethodCalls ImplicitNewlines)
  $self->set_title( 'BLAST tools' )
       ->set_navigation_path( '/resources/software/' )
       ->set_introduction( {
    'caption' => 'BLAST tool',
    'body'    => '
      <p>
        Either enter the ticket id for a previous ticket,
        or start a new blast with the form below.
      </p>
      <form action="/action/Js5Blast" class="check">
        <div>
        <dl>
          <dt class="fifty50"><label for="ticket_id">Retrieve previous BLAST ticket:</label></dt>
          <dd class="fifty50"><input id="ticket_id" name="ticket_id" class="_string medium required" size="20"/></dd>
        </dl>
        <div class="button-row">
          <div class="button-default">
            <input class="next invalid" id="button_next" name="next" value="Retrieve&raquo;" title="Retrieve ticket" type="submit" />
          </div>
        </div>
        </div>
      </form>
    ' });
  $self->add_class(  'form',                 'check' )          # Javascript validation is enabled
       ->add_class(  'section',              'panel' )          # Form sections are wrapped in panels
       ->add_class(  'progress',             'panel' )          # Progress section is wrapped in panels
       ->add_class(  'progress',             'form-progress' )          # Progress section is wrapped in panels
       ->add_class(  'layout',               'fifty50' )
       ->set_option( 'validate_before_next', 1 )  # Form must
       ->set_option( 'progress_panel',       1 )  # We have a progress panel
       ->set_option( 'progress_navigation',  1 )  # Progress panel is navigable
       ->set_option( 'back_button',          1 )  # We have a back button on every page
       ->set_option( 'cancel_button',        1 )  # Form has a cancel button
       ->set_option( 'form_title',           'BLAST submission' )    #
       ->set_option( 'progress_caption',     'Progress' );
  ## Stage 1 - get sequence, database & program!
  $self->input_stage;
  ## Stage 2 - confirm we have details correct...
  $self->confirmation_stage;
  ## Stage 3 - we have submitted request .... (could add a confirmation stage)
  $self->submit_stage;
  return $self;
}

sub submit_stage {
  my $self = shift;
  $self->add_final_stage( 'submitted' );
    ##no critic (ImplicitNewlines)
    $self->add_raw_section(
      '<p>
        Your blast has been submitted - bookmark this page to see the current status...
       </p>
       <% Blast_Status -ajax '.($self->code||q()).q( %>
      ),
      'Thank you' );
    ## use critic
    $self->add_readonly_section;
  return;
}

sub confirmation_stage {
  my $self = shift;
  $self->add_confirmation_stage( 'check' )->set_next( 'Run' );
    $self->add_raw_section(
      '<p>Please check the details below and then click Run to submit your BLAST</p>',
      'Thank you' );
    $self->add_readonly_section;
  return;
}

sub input_stage {
  my $self = shift;
  $self->add_stage( 'query_sequence' );
    $self->add_query_seq_section;
    $self->add_db_and_program_section;
    $self->add_blastn_options('megablast');
    $self->add_blastn_options('dc-megablast');
    $self->add_blastn_options('blastn');
    $self->add_blastp_tblastn_options;
    $self->add_blastx_tblastx_options;
    $self->add_section( 'x', q() );
  return;
}

sub add_query_seq_section {
  my $self = shift;
  $self->add_section( 'query_sequence' );
    $self->add( 'Fasta', 'fasta' )
      ->set_notes( 'Paste your sequence here. fasta format or just plain text will do.' )
      ->remove_layout( 'fifty50' );
    $self->add( 'FastaFile', 'fasta_file' )->remove_layout('fifty50')->set_optional;
  return;
}

sub add_db_and_program_section {
  my $self = shift;
  $self->add_section( 'database_and_program' );
    $self->add( 'String', 'species' )->set_readonly->set_raw;
    $self->add( 'DropDown', 'database' )->set_raw;
    $self->add( 'DropDown', 'program' )->add_class( 'logic_change');
    $self->add( 'DropDown', 'num_alignments' )->set_caption( 'Alignments returned' )
      ->set_values([ qw(10 25 50 100 250 500 1000) ])
      ->set_default_value('100');
    $self->add( 'DropDown', 'task' )->add_class( 'logic type-1-all act-1-enable node-1-exact-program-blastn logic_change' )
      ->set_caption( 'Optimize for' )
      ->add_logic( 'enable', 'all', { 'name'=> 'program', 'type' => 'exact', 'value' => 'blastn' }, ) ## Disabled unless [program]=='blastn'
      ->set_values([
        { 'value' => 'megablast',    'name' => 'Highly similar sequences (megablast)' },
        { 'value' => 'dc-megablast', 'name' => 'More dissimilar sequences (discontiguous megablast)' },
        { 'value' => 'blastn',       'name' => 'Somewhat similar sequences (blastn)' },
      ]);
  return;
}

sub add_blastn_options {
  my ($self, $task) = @_;
  my %default;
  if($task eq 'megablast'){
    $default{'score'} = '1,-2';
    $default{'dust'} = 'no';
    $default{'lcase_masking'} = 'no';
    $default{'soft_masking'} = 'yes';
  }
  else{
    $default{'score'} = '2,-3';
    $default{'dust'} = 'yes';
    $default{'lcase_masking'} = 'no';
    $default{'soft_masking'} = 'yes';
  }

  $self->add_section( $task.'_options' )->add_logic( 'enable',  'all',
    { 'name'=> 'program', 'type' => 'exact', 'value' => 'blastn' },
    { 'name'=> 'task',   'type' => 'exact', 'value' => $task },
  )->add_class( qq{logic type-1-all act-1-enable node-1-exact-program-blastn node-1-exact-task-$task} );
    $self->add_evalue($task);
    $self->add_word_size($task);
    $self->add_score($task, $default{'score'});
    $self->add_gap_costs($task);
    $self->add_dust($task, $default{'dust'});
    $self->add_lcase_masking($task, $default{'lcase_masking'});
    $self->add_soft_masking($task, $default{'soft_masking'});
    return;
}

sub add_blastp_tblastn_options {
  my $self = shift;
  $self->add_section( 'blastp_options', 'Blastp and tblastn options' )->add_logic( 'enable',  'any',
    { 'name'=> 'program', 'type' => 'exact', 'value' => 'blastp' },
    { 'name'=> 'program', 'type' => 'exact', 'value' => 'tblastn' },
  )->add_class( 'logic type-1-any act-1-enable node-1-exact-program-blastp node-1-exact-program-tblastn' );
    $self->add_evalue('blastp_tblastn');
    $self->add_word_size('blastp_tblastn');
    $self->add_matrix('blastp_tblastn');
    $self->add_gap_costs('blastp_tblastn');
    $self->add_comp_based_stats('blastp_tblastn');
    $self->add_seg('blastp_tblastn', 'no');
    $self->add_lcase_masking('blastp_tblastn', 'no');
    $self->add_soft_masking('blastp_tblastn', 'no');
    return;
}

sub add_blastx_tblastx_options {
  my $self = shift;
  $self->add_section( 'blastx_options', 'Blastx and tblastx options')->add_logic( 'enable',  'all',
    { 'name'=> 'program', 'type' => 'ends_with', 'value' => 'blastx' },
  )->add_class( 'logic type-1-all act-1-enable node-1-ends_with-program-blastx' );
    $self->add_strand('blastx_tblastx');
    $self->add_query_gencode('blastx_tblastx');
    $self->add_evalue('blastx_tblastx');
    $self->add_word_size('blastx_tblastx');
    $self->add_matrix('blastx_tblastx');
    $self->add_gap_costs('blastx_tblastx');
    $self->add_seg('blastx_tblastx', 'yes');
    $self->add_lcase_masking('blastx_tblastx', 'no');
    $self->add_soft_masking('blastx_tblastx', 'no');
    return;
}

sub add_query_gencode{
  my ($self, $type) = @_;
  $self->add( 'DropDown', $type.'_query_gencode' )->set_caption( 'Genetic code' )->set_values([
    { 'value' => '1',  'name' => 'Standard' },
    { 'value' => '2',  'name' => 'Vertebrate Mitochondrial' },
    { 'value' => '3',  'name' => 'Yeast Mitochondrial' },
    { 'value' => '4',  'name' => 'Mold Mitochondrial' },
    { 'value' => '5',  'name' => 'Invertebrate Mitochondrial' },
    { 'value' => '6',  'name' => 'Ciliate Nuclear' },
    { 'value' => '9',  'name' => 'Echinoderm Mitochondrial' },
    { 'value' => '10', 'name' => 'Euplotid Nuclear' },
    { 'value' => '11', 'name' => 'Bacteria and Archaea' },
    { 'value' => '12', 'name' => 'Alternative Yeast Nuclear' },
    { 'value' => '13', 'name' => 'Ascidian Mitochondrial' },
    { 'value' => '14', 'name' => 'Flatworm Mitochondrial' },
    { 'value' => '15', 'name' => 'Blepharisma Macronuclear' },
  ])->set_default_value( '1' );
  return;
}

sub add_strand{
  my ($self, $type) = @_;
  $self->add( 'DropDown', $type.'_strand' )
    ->set_values([ qw(both minus plus) ])
    ->set_default_value( 'both' );
  return;
}

sub add_seg {
  my ($self, $type, $default) = @_;
  $self->add( 'YesNo', $type.'_seg' )
    ->set_caption( 'Filter low complexity regions (Should be yes for tblastn)' )
    ->set_default_value($default)
    ->set_layout( 'fifty50' );
  return;
}

sub add_comp_based_stats {
  my ($self, $type) = @_;
  $self->add( 'DropDown', $type.'_comp_based_stats' )->set_caption( 'Compositional adjustments' )->set_values([
    { 'value' => '0', 'name' => 'No adjustments' },
    { 'value' => '1', 'name' => 'Composition based statisics' },
    { 'value' => '2', 'name' => 'Conditional compositional score matrix adjustment' },
    { 'value' => '3', 'name' => 'Universal compositional score matrix adjustment' },
  ])->set_default_value( '2' );
  return;
}

sub add_matrix {
  my ($self, $type) = @_;
  $self->add( 'DropDown', $type.'_matrix' )->set_values([ qw(PAM30 PAM70 BLOSUM80 BLOSUM62 BLOSUM45) ])
    ->set_default_value( 'BLOSUM62' );
  return;
}

sub add_soft_masking {
  my ($self, $type, $default) = @_;
  $self->add( 'YesNo', $type.'_soft_masking' )
    ->set_caption( 'Soft masking' )
    ->set_default_value($default)
    ->set_layout( 'fifty50' );
  return;
}

sub add_lcase_masking {
  my ($self, $type, $default) = @_;
  $self->add( 'YesNo', $type.'_lcase_masking' )
    ->set_caption( 'Lower case masking' )
    ->set_default_value($default)
    ->set_layout( 'fifty50' );
  return;
}

sub add_dust {
  my ($self, $type, $default) = @_;
  $self->add( 'YesNo', $type.'_dust' )
    ->set_caption( 'Filter low complexity regions' )
    ->set_default_value($default)
    ->set_layout( 'fifty50' );
  return;
}


sub add_gap_costs {
  my ($self, $type) = @_;
  given($type){
    when('megablast'){
      $self->add( 'DropDown', $type.'_gap_costs' )->set_values([
        { 'value' => '0,0', 'name' => 'Linear' },
        { 'value' => '5,2', 'name' => 'Existence: 5 Extension: 2' },
        { 'value' => '2,2', 'name' => 'Existence: 2 Extension: 2' },
        { 'value' => '1,2', 'name' => 'Existence: 1 Extension: 2' },
        { 'value' => '0,2', 'name' => 'Existence: 0 Extension: 2' },
        { 'value' => '3,1', 'name' => 'Existence: 3 Extension: 1' },
        { 'value' => '2,1', 'name' => 'Existence: 2 Extension: 1' },
        { 'value' => '1,1', 'name' => 'Existence: 1 Extension: 1' },
      ])->set_default_value( '0,0' );
    }
    when('dc-megablast' || 'blastn'){
      $self->add( 'DropDown', $type.'_gap_costs' )->set_values([
        { 'value' => '4,4', 'name' => 'Existence: 4 Extension: 4' },
        { 'value' => '2,4', 'name' => 'Existence: 2 Extension: 4' },
        { 'value' => '0,4', 'name' => 'Existence: 0 Extension: 4' },
        { 'value' => '3,3', 'name' => 'Existence: 3 Extension: 3' },
        { 'value' => '6,2', 'name' => 'Existence: 6 Extension: 2' },
        { 'value' => '5,2', 'name' => 'Existence: 5 Extension: 2' },
        { 'value' => '4,2', 'name' => 'Existence: 4 Extension: 2' },
        { 'value' => '2,2', 'name' => 'Existence: 2 Extension: 2' },
      ])->set_default_value( '5,2' );
    }
    default {
      $self->add( 'DropDown', $type.'_gap_costs' )->set_values([
        { 'value' => '9,2',  'name' => 'Existence: 9 Extension: 2' },
        { 'value' => '8,2',  'name' => 'Existence: 8 Extension: 2' },
        { 'value' => '7,2',  'name' => 'Existence: 7 Extension: 2' },
        { 'value' => '12,1', 'name' => 'Existence: 12 Extension: 1' },
        { 'value' => '11,1', 'name' => 'Existence: 11 Extension: 1' },
        { 'value' => '10,1', 'name' => 'Existence: 10 Extension: 1' },
      ])->set_default_value( '11,1' );
    }
  }
  return;
}

sub add_score {
  my ($self, $type, $default) = @_;
  $self->add( 'DropDown', $type.'_scores' )->set_caption('Match/Mismatch Scores')
    ->set_values([ '1,-2', '1,-3', '1,-4', '2,-3', '4,-5', '1,-1', ])
    ->set_default_value( $default );
  return;
}

sub add_evalue {
  my ($self, $type) = @_;
  $self->add( 'DropDown', $type.'_evalue' )->set_caption( 'Expect (E)' )
    ->set_values([ qw(0.0001 0.001 0.01 0.1 1 10 100 1000 10000) ])
    ->set_default_value( '10' );
  return;
}

sub add_word_size {
  my ($self, $type) = @_;
  given($type){
    when('megablast'){
      $self->add( 'DropDown', $type.'_word_size' )
        ->set_values([ qw( 16 20 24 28 32 48 64 128 256 ) ])
        ->set_default_value( '28' );
    }
    when('dc-megablast'){
      $self->add( 'DropDown', $type.'_word_size' )
        ->set_values([ qw( 11 12 ) ])
        ->set_default_value( '11' );
    }
    when('blastn'){
      $self->add( 'DropDown', $type.'_word_size' )
        ->set_values([ qw( 7 11 15 ) ])
        ->set_default_value( '11' );
    }
    default {
      $self->add( 'DropDown', $type.'_word_size' )
        ->set_values([ qw( 2 3 ) ])
        ->set_default_value( '3' );
    }
  }
  return;
}
## use critic
1;
