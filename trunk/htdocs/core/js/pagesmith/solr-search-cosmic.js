(function(){
  'use strict';
  var searcher = new Pagesmith.SolrSearch();
  searcher.set_search_url( '/solr-sanger/cosmic/sanger');
  searcher.init();
  searcher.add_template( 'ensembl', {
    title:  [ 'id' ],
    link:   [ 'website','/','domain_url'],
    fields: {description:'Description',species:'Species',feature_type:'Feature type'},
    label:  'Ensembl'
  } );
  searcher.add_template( 'Annotrack', {
    title:  [ 'name' ],
    link:   [ 'website', 'domain_url' ],
    fields: { description:'Description',species:'Species',type:'Type'},
    label:  'Annotrack'
  } );
  searcher.add_template( 'Merops', {
    title:  [ 'name' ],
    link:   [ 'website', 'domain_url', 'id' ],
    fields: { id: 'Accession', description:'Description' },
    label:  'Merops'
  } );
  searcher.add_template( 'Pfam', {
    title:  [ 'id' ],
    link:   [ 'website', 'domain_url', 'id' ],
    fields: { description:'Description', pfamA_acc:'Accession' },
    label:  'Pfam'
  } );
  searcher.add_template( 'cosmic', {
    title:  [ 'name' ],
    link:   [ 'http://', 'website', 'url_action', 'url_link_id' ],
    fields: { description:'Description', alt_ids: 'Alternative identifiers', data_type:'Type'},
    label:  'COSMIC'
  } );
  searcher.add_template( 'cosmic_wg', {
    title:  [ 'name' ],
    link:   [ 'http://', 'website', 'url_action', 'url_link_id' ],
    fields: { description:'Description', alt_ids: 'Alternative identifiers', data_type:'Type'},
    label:  'COSMIC whole genome '
  } );
  searcher.add_template( 'cosmic_cl', {
    title:  [ 'name' ],
    link:   [ 'http://', 'website', 'url_action', 'url_link_id' ],
    fields: { description:'Description', data_type:'Type'},
    label:  'COSMIC cell line'
  } );
  searcher.add_alias('ensembl','http://www.ensembl.org');
  searcher.search();
}());
