/*----------------------------------------------------------------------
  Collapseable code

  author: js5 (James Smith)
  svn-id: $Id$
------------------------------------------------------------------------
  Dependency: none
----------------------------------------------------------------------*/

$('div.collapsible p.head, div.collapsible h3, div.collapsible h4.keep').livequery(function () {
  $(this).prepend('<img src="/core/gfx/blank.gif" />').bind('click', function () {
    $(this).closest('div.collapsible').toggleClass('collapsed');
  });
});
