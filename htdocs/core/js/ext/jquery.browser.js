(function( jQuery, window, undefined ) {
  'use strict';
  var  ua = window.navigator.userAgent.toLowerCase(),
    match = ( /(chrome)[ \/]([\w.]+)/.exec( ua )              ) ||
            ( /(webkit)[ \/]([\w.]+)/.exec( ua )              ) ||
            ( /(opera)(?:.*version|)[ \/]([\w.]+)/.exec( ua ) ) ||
            ( /(msie) ([\w.]+)/.exec( ua )                    ) ||
            ua.indexOf('compatible') < 0 && ( /(mozilla)(?:.*? rv:([\w.]+)|)/.exec( ua ) ) || [];
  jQuery.browser = { version:0 };
  if( match ) {
    jQuery.browser[ match[1] ] = true;
    if( match[1] === 'chrome' ) {
      jQuery.browser.webkit = true;
    } else if ( match[1] === 'webkit' ) {
      jQuery.browser.safari = true;
    }
    jQuery.browser.version = match[2];
  }
}) (jQuery,window);
