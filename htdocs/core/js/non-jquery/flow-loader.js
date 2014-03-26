/* globals flowplayer */
(function(){
  'use strict';
  var x = document.getElementsByTagName('A'), i, t, m;
  for(i=x.length;i;i) {
    i--;
    t = x[i];
    m = t.className.match(/flowplay.*key:'([^']+)'/);
    if( m ) {
      flowplayer( t.id, '/s-inst/assets/flowplayer.commercial-3.2.18.swf', {
        key: m[1],
        clip: { autoPlay: false, autoBuffering: true, accelerated: true, title: t.title }
      });
    }
  }
}());
