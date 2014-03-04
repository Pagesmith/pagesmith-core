(function($){
  'use strict';
  /*----------------------------------------------------------------------
    Collapseable code

    author: js5 (James Smith)
    svn-id: $Id$
  ------------------------------------------------------------------------
    Dependency: none
  ----------------------------------------------------------------------*/

  $('div.collapsible p.head, div.collapsible h3, div.collapsible h4.keep').livequery(function () {
    $(this).prepend(
      $(this).closest('div.collapsible').hasClass('collapsed') ? '<span>&#x25ba;</span>': '<span>&#x25bc;</span>'
    ).bind('click', function () {
      $(this).closest('div.collapsible').toggleClass('collapsed');
      $(this).find('span').eq(0).html( $(this).closest('div.collapsible').hasClass('collapsed') ? '&#x25ba;' : '&#x25bc' );
    });
  });
}(jQuery));
