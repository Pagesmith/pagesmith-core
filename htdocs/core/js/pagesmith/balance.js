(function($){
  'use strict';

  function balance_columns(o) {
    var max = 0, a, z;
    /* First check to see if we have collapsed the page sufficiently that the columns
       are one above the other - if so just set to auto and skip the rest of the function */
    var mnl = 1e99;
    var mxl = 0;
    o.closest('.balance').find('.panel').each(function () {
      var l = $(this).position().left;
      if( l < mnl ) { mnl = l; }
      if( l > mxl ) { mxl = l; }
    });
    if( mxl === mnl ) {
      o.height('auto');
      return;
    }
    /* We know these are side by side so bring balance to the force */
    o.closest('.balance').find('.panel').each(function () {
      a = $(this).height();                  // Grab height;
      z = $(this).height('auto').height();   // Reset it to auto and get new value
      $(this).height(a);                     // Reset height to previous value
      if (z > max) {                         // Check if greater than previous heighest value
        max = z;
      }
    });
    o.height(max);                 // Make div the height of the tallest "sibling"
  }

  // Initial appearance
  Pagesmith.On.all_load( '.balance .panel', function () {
    $(this).each(function () { balance_columns($(this)); });
  });

  // Every time the page is resized
  $(window).resize(function () {
    $('.balance .panel').each(function () {
      balance_columns($(this));
    });
  });

  var lastHeight = 0;
  function pollSize() {
    var newHeight = $(window).height();
    if (lastHeight === newHeight) {
      return;
    }
    lastHeight = newHeight;
    $(window).resize();
  }
  window.setInterval(pollSize, 250);
}(jQuery));
