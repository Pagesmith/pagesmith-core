(function(){
  'use strict';
  var t = document.getElementsByTagName('table'), i, b, r, j;
  for (i = t.length; i; i)   {
    i--;
    if (t[i].className.match(/\b(zebra|sorted)-table\b/)) {
      b = t[i].getElementsByTagName('tbody');
      if (b.length) {
        r = b[0].getElementsByTagName('tr');
        for (j = r.length; j; j)   {
          j--;
          if (j % 2) {
            r[j].className = r[j].className + ' odd';
          }
        }
      }
    }
  }
}());
