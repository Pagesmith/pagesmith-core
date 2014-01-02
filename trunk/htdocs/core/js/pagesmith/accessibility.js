(function($){
  /*----------------------------------------------------------------------
    Accessibilty code

    author: js5 (James Smith)
    svn-id: $Id$
  ------------------------------------------------------------------------
    Code to change the font size via the "a...a" buttons
  ----------------------------------------------------------------------*/

  'use strict';
  Pagesmith.accessibility = {
    set: function (sz) {
      if (sz !== Pagesmith.flags.z) {
        Pagesmith.flags.z = sz;
        Pagesmith.setCookie();
      }
      $('body').attr('class', 's-' + sz);
      $(window).resize();
    },
    init: function () {
      $('#access').find('span').click(function () {
        Pagesmith.accessibility.set($(this).attr('id').substr(2, 1));
      });
      Pagesmith.accessibility.set(Pagesmith.flags.z || 'n');
    }
  };
  Pagesmith.accessibility.init();
}(jQuery));
