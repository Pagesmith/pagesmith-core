(function($){
  'use strict';
  /*----------------------------------------------------------------------
    Feed code
  ------------------------------------------------------------------------
    Dependency:
  ------------------------------------------------------------------------
    Munge all feed elements to collapse their descriptions and
    add hide/collapse buttons
  ----------------------------------------------------------------------*/

  function feed_buttons(obj) {
    obj
      .addClass('munged')
      .prepend('<img class="feed_img" src="/core/gfx/blank.gif" />')
      .filter(function () {
        return $(this).children('.feed_tog').length > 0;
      })
      .children('.feed_img')
      .addClass('feed_exp');
    $('.feed_tog').hide();
    $('.feed_exp').click(function () {
      feed_buttons.collapse_all();
    // Convert toggle button for this feed...
    // And toggle div!
      $(this)
        .removeClass('feed_exp').addClass('feed_col')
        .closest('li').children('.feed_tog').show();
    });
    $('.feed_col').click(feed_buttons.collapse_all);
  }

  feed_buttons.collapse_all = function () {
    $('.feed_tog').hide(); // Hide all feed panels...
    $('.feed_col').removeClass('feed_col').addClass('feed_exp'); // Convert all "feed collapse" buttons to "feed expand buttons"
  };

  Pagesmith.On.load( '.feed li', function() {
    if (!$(this).hasClass('munged')) {
      feed_buttons($(this));
    }
  });
}(jQuery));
