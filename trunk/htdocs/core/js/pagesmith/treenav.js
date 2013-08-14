$('.branch > span').on( 'click', function(){ $(this).parent().toggleClass('coll');return false; } );

$(document).ready(function() {
  // to show it in an alert window
  var link_node = $('a[href="'+window.location.pathname+'"]');
  link_node.parents('.coll').toggleClass('coll');
});
