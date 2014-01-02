(function(){
  'use strict';
  var x = document.getElementsByTagName('A'), i, t, m = document.location.href.match( /https?:\/\/([^\/]+)/ ), domain = '';
  if( m ) {
    domain = m[1];
  }
  for (i = x.length; i; i) {
    i--;
    t = x[i];
    m = t.href.match( /^https?:\/\/([^\/]+)/ );
    if( m && m[1]!==domain || t.rel === 'external'  ) {
      t.target = '_blank';
      t.title = '* This link opens in a new window to ' + t.href;
    }
  }
}());
