var x = document.getElementsByTagName('A'), i, t;
for (i = x.length; i; i) {
  i--;
  t = x[i];
  if (t.rel === 'external') {
    t.target = '_blank';
    t.title = '* This link opens in a new window to ' + t.href;
  }
}
