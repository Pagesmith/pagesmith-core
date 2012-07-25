/**
 * $().tabs - extends jQuery object with a simple tab call - $('.tabs').tabs();
 * Function closes down hidden tabs - and add's functionality to the tab
 * links to hide/show the appropriate link.
 */
jQuery.fn.tabs = function (no_top_border) {
  /* Activate first tab, and for each of it's siblings hide the
     tab content..... */
  // Disable all tabs for which there is no associated div tab!
  jQuery(this).children('li').each(function () {
    if (!$($(this).children('a').prop('hash')).addClass(no_top_border ? 'tabc no-top-border' : 'tabc').length && !$(this).hasClass('action')) {
      $(this).addClass('disabled');
    }
  });

  /* For each child in the list - add an on-click function which shows the
     relevant tab content - after first hiding the other tabs */

  jQuery(this).children('li').children('a').click(function (ev) {
    if ($(this).closest('li').hasClass('disabled')) { // Only do something for enabled tabs!
      return false;
    }
    // De-activate all other tabs.. and hide their associated content.
    $(this).closest('li').addClass('active').siblings('li').each(function () {
      $(this).removeClass('active');
      $($(this).children('a').prop('hash')).addClass('tabc_hid');
    });
    if ($(this).closest('li').hasClass('action')) {
      $(this).closest('li').removeClass('active');
    }
    // Show the content associated with this tab
    // - note we have to do it this way round to stop bumping
    $($(this).prop('hash')).removeClass('tabc_hid');
//    $($(this).prop('hash')).parents('.tabc_hid').each(function () {
 //     var id_sel = ' a[href=#' + $(this).attr('id') + ']';
//      $('.tabs' + id_sel + ', .fake-tabs' + id_sel).click();
//    });
    return false;
  });
  // Activate the first tab
  var x = $(this).children('li.active'); //Find first enabled tab!
  if (!x.length) {
    x = $(this).children('li:not(.disabled)'); //Find first enabled tab!
    x.first().children('a').click();
  }
};

  // Finally if the URL contains an anchor - open the tab (if it is a tab!)
/**
 * Live query block - which attaches tab functionality to any list item
 * of class tabs
 */
$('.tabs').livequery(function () { $(this).tabs(0); });
$('.fake-tabs').livequery(function () { $(this).tabs(1); });

var id_str = window.location.hash;
if (id_str && id_str.match(/^#[-\w]+$/)) {
  var id_sel = ' > li > a[href=' + id_str + ']';
  $('.tabs' + id_sel + ', .fake-tabs ' + id_sel).click().parents('.tabc_hid').each(function () {
    var id_sel = ' a[href=#' + $(this).attr('id') + ']';
    $('.tabs' + id_sel + ', .fake-tabs' + id_sel).click();
  });

}

/**
 * Live query block - which (on links of class "change-tab") activates
 * the tab indicated by the href of the link.
 */

$('.change-tab').live('click', function () {
  var x = ' li a[href=' + $(this).prop('hash') + ']';
  $('.tabs' + x + ', .fake-tabs' + x).click().parents('.tabc_hid').each(function () {
    var id_sel = ' a[href=#' + $(this).attr('id') + ']';
    $('.tabs' + id_sel + ', .fake-tabs' + id_sel).click();
  });
  return false;
});

$('.enable-tab').livequery(function () {
  $('.tabs li a[href=' + $(this).prop('hash') + ']').closest('li').removeClass('disabled');
});
