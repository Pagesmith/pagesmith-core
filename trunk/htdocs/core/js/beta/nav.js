(function($){
  'use strict';
  $('.branch span').on( 'click', function(){ $(this).parent().toggleClass('coll');return false; } );

  $(document).ready(function() {
    // to show it in an alert window
    var link_node = $('a[href="'+window.location.pathname+'"], a[href="'+window.location.pathname.replace(/^.*\/([^\/]+)$/,'$1')+'"]');
    link_node.parents('.coll').toggleClass('coll');
  });

  $('body')
    .on('click','#main  .toggle-width',function() { $('#main').attr('id','mainx'); $('#rhs').attr('id','rhsx'); $(this).html('&gt;=&lt;');} )
    .on('click','#mainx .toggle-width',function() { $('#mainx').attr('id','main'); $('#rhsx').attr('id','rhs'); $(this).html('&lt;=&gt;');} );
}(jQuery));
