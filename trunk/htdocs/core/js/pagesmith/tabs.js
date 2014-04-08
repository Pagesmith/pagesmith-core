
(function($){
  'use strict';
  /**
   * $().tabs - extends jQuery object with a simple tab call - $('.tabs').tabs();
   * Function closes down hidden tabs - and add's functionality to the tab
   * links to hide/show the appropriate link.
   */

  Pagesmith.tab_click = function( ths ) {
 //   var id = $(this).prop('hash');
    if( $(ths).closest('li').hasClass('disabled')) { // Only do something for enabled tabs!
      return false;
    }
    // De-activate all other tabs.. and hide their associated content.
    $(ths).closest('li').addClass('active').siblings('li').each(function () {
      $(this).removeClass('active');
      $($(this).children('a').prop('hash')).addClass('tabc_hid');
    });
    if ($(ths).closest('li').hasClass('action')) {
      $(ths).closest('li').removeClass('active');
    }
    // Show the content associated with this tab
    // - note we have to do it this way round to stop bumping
    $($(ths).prop('hash')).removeClass('tabc_hid');
  //    $($(this).prop('hash')).parents('.tabc_hid').each(function () {
  //     var id_sel = ' a[href=#' + $(this).attr('id') + ']';
  //      $('.tabs' + id_sel + ', .fake-tabs' + id_sel).click();
  //    });
    Pagesmith.On.all_flush();
    return false;
  };

  jQuery.fn.tabs = function (no_top_border) {
    /* Activate first tab, and for each of it's siblings hide the
       tab content..... */
    // Disable all tabs for which there is no associated div tab!
  //  var id = jQuery(this).find('a').eq(0).prop('hash');

    jQuery(this).children('li').each(function () {
      if (!$($(this).children('a').prop('hash')).addClass(no_top_border ? 'tabc no-top-border' : 'tabc').length && !$(this).hasClass('action')) {
        $(this).addClass('disabled');
      }
    });
    /* For each child in the list - add an on-click function which shows the
       relevant tab content - after first hiding the other tabs */

    jQuery(this).children('li').children('a').click(function(){ return Pagesmith.tab_click(this);});
    // Activate the first tab
    var x = $(this).children('li.active'); //Find first enabled tab!
    if (!x.length) {
      x = $(this).children('li:not(.disabled)'); //Find first enabled tab!
      x.first().children('a').click();
    }
    return;
  };

    // Finally if the URL contains an anchor - open the tab (if it is a tab!)
  /**
   * Live query block - which attaches tab functionality to any list item
   * of class tabs
   */
  Pagesmith.On.load(
    '.tabs', function () { $(this).tabs(0); }
  ).load(
    '.fake-tabs', function () { $(this).tabs(1); }
  ).load( '.enable-tab', function () {
    $('.tabs li a[href=' + $(this).prop('hash') + ']').closest('li').removeClass('disabled');
  });
  function fire_tabs( hash_sel, hash_details ) {
    var id_sel = ' > li > a[href='+ hash_sel +']',
        Z      = $('.tabs' + id_sel + ', .fake-tabs ' + id_sel),
        e;
    if( Z.length ) {
      Z.click().parents('.tabc_hid').each(function () {
        var parent_id_sel = ' > li > a[href=#' + $(this).attr('id') + ']';
        $('.tabs' + parent_id_sel + ', .fake-tabs' + parent_id_sel).click();
      });
      if( hash_details.length ) {
        var x = hash_details.shift();
        x = '#'+x;
        fire_tabs( x, hash_details );
      }
      return;
    }

    hash_details.unshift( hash_sel );
    e = $(hash_details.join(' ')).get();
    if( e.length ) {
      e[0].scrollIntoView();
    }
  }

  /**
   * Live query block - which (on links of class "change-tab") activates
   * the tab indicated by the href of the link.
   */

  $(function(){
    var id_str = window.location.hash;
    if (id_str && id_str.match(/^#[- \w]+$/)) {
      var hash_details = id_str.split(/ +/), hash;
      hash = hash_details.shift();
      fire_tabs( hash, hash_details );
    }
  });

  $(document).on('click', '.change-tab', function () {
    var hash_details = $(this).prop('hash').split(/ +/),
        hash = hash_details.shift();
    fire_tabs( hash, hash_details );
    return false;
  });

  Pagesmith.On.show('.tabc', function(){
    var list = $(this).attr('class').split(/\s+/),j,m;
    for(j=list.length;j;j) {
      j--;
      m = list[j].match(/onshow_(\w+)/);
      if(m) {
        fire_tabs( '#'+m[1], [] );
      }
    }
  });
}(jQuery));
