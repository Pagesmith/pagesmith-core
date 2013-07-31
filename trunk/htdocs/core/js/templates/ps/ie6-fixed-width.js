/**
 * Min/max width emulator for IE6. Emulates min/max width of other browsers
 * in Internet Explorer 6
 * @author:   js5 (James Smith)
 * @version:  $Id$
 * @requires: jQuery
 */

$(function () {
  if (typeof document.body.style.maxHeight === "undefined" && $('body').attr('id') !== 'homepage') { //if IE 6
    $(window).on('resize',function () {
      var X = Math.min( Math.max( $(window).width() - 20, 780 ), 1380 );
      if( $('#outer').width() !== X ) {
        $('#outer').width(X);
      }
    });
    $(window).resize();
  }
});
