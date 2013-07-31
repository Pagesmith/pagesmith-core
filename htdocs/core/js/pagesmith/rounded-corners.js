/**
 * Rounded corner box code.
 * Replace class="panel" divs with a cb div containing wrappers and
 * padders to place the background graphics onto the page.... and to
 * adjust the spacing.
 * @author: James Smith - derived from cbb function by Roger Johansson, http://www.456bereastreet.com/
 * @version: $Id$
 * @require: jQuery, jquery.livequery.js
 */

jQuery.fn.rounded_corners = function () {
  jQuery(this)
    .addClass('cb')
    .wrapInner('<div class="i1"><div class="i2"><div class="i3"></div></div></div>')
    .each(function () {
      $(this)
        .children(':first')
        .before('<div class="bt"><div></div></div>')
        .after('<div class="bb"><div></div></div>');
    })
    .removeClass('panel');
};

/**
 * Live query block to perform the above function on all divs of class "panel"
 */

$('.panel').livequery(function () {
  $(this).rounded_corners();
});

/*
  wrapping multiple panels in a "balance" tag will mean that they will be given the same height

  this gets run every time one appears in the system
*/

function balance_columns(o) {
  var max = 0, a, z;
  o.closest('.balance').find('.i3').each(function () {
    a = $(this).height();                  // Grab height;
    z = $(this).height('auto').height();   // Reset it to auto and get new value
    $(this).height(a);                         // Reset height to previous value
    if (z > max) {                      // Check if greater than previous heighest value
      max = z;
    }
  });
  o.height(max);                 // Make div the height of the tallest "sibling"
}

// Initial appearance
$('.balance .i3').livequery(function () {
  $(this).each(function () { balance_columns($(this)); });
});

// Every time the page is resized
$(window).resize(function () {
  $('.balance .i3').each(function () {
    balance_columns($(this));
  });
});

var lastHeight = 0;
function pollSize() {
  var newHeight = $(window).height();
  if (lastHeight === newHeight) {
    return;
  }
  lastHeight = newHeight;
  $(window).resize();
}
window.setInterval(pollSize, 250);
