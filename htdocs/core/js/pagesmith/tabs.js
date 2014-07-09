
(function($){
  'use strict';
  /**
   * $().tabs - extends jQuery object with a simple tab call - $('.tabs').tabs();
   * Function closes down hidden tabs - and add's functionality to the tab
   * links to hide/show the appropriate link.
   */
  var hc_flag = 0;
  var track_tabs = 0;
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
    // This is where we need to update what has been clicked on!
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
  Pagesmith.update_tab_list = function( ths ) {
    if( ! track_tabs ) {
      return;
    }
    var id_str = window.location.hash,
      m, i,
      id,
      ids_to_remove,
      new_tab_list = [],
      tab_list = [];

    if( id_str ) {
      m = id_str.match(/tabs=([-| \w]+)/);
      if( m ) {
        tab_list = m[1].split(/\|/);
      }
    }
    id = $(ths).prop('hash');
    ids_to_remove = {};
    ids_to_remove[ id ] = 1;
    $(ths).closest('li').siblings('li').children('a').each(function(){
      ids_to_remove[ $(this).prop('hash') ] = 1;
    });
    for( i in tab_list ) {
      if( ! ids_to_remove[ '#'+tab_list[i] ] ) {
        new_tab_list.push( tab_list[i] );
      }
    }
    new_tab_list.push( id.substring(1) );
    var z = '#tabs='+new_tab_list.join('|');
    if( window.location.hash !== z ) {
      hc_flag = 1;
      window.location.hash = z;
    }
    return false;
  };
  $(window).hashchange( function(){
    if( hc_flag === 1 ) {
      hc_flag = 0;
      return;
    }
    Pagesmith.on_page_load_hash();
  } );
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

    jQuery(this).children('li').children('a').on('click',function(){
      Pagesmith.tab_click(this);
      return Pagesmith.update_tab_list(this);
    });
    // Activate the first tab
    var x = $(this).children('li.active'); //Find first enabled tab!
    if (!x.length) {
      x = $(this).children('li:not(.disabled)'); //Find first enabled tab!
    }
    if( ! $(this).hasClass('rolledup') ) {
      Pagesmith.tab_click( x.first().children('a') );
    }
    $(this).addClass('rolledup');
    return;
  };

    // Finally if the URL contains an anchor - open the tab (if it is a tab!)
  /**
   * Live query block - which attaches tab functionality to any list item
   * of class tabs
   */
  if( $('body').hasClass('track-tabs') ) {
    track_tabs = 1;
  }
  Pagesmith.On.load(
    '.tabs', function () { $(this).tabs(0); }
  ).load(
    '.fake-tabs', function () { $(this).tabs(1); }
  ).load( '.enable-tab', function () {
    $('.tabs li a[href=' + $(this).prop('hash') + ']').closest('li').removeClass('disabled');
  });

  function fire_tabs( hash_sel, hash_details ) {
    if( '#' !== hash_sel.charAt(0) ) {
      hash_sel = '#'+hash_sel;
    }
    var id_sel = ' > li > a[href='+ hash_sel +']',
        Z      = $('.tabs' + id_sel + ', .fake-tabs ' + id_sel),
        e;
    if( Z.length ) {
      Pagesmith.tab_click( Z );
      Z.parents('.tabc_hid').each(function () {
        var parent_id_sel = ' > li > a[href=#' + $(this).attr('id') + ']';
        $('.tabs' + parent_id_sel + ', .fake-tabs' + parent_id_sel).each(function(){Pagesmith.tab_click(this);});
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

  Pagesmith.on_page_load_hash = function() {
    var id_str = window.location.hash,z,hash,hash_details,i,m;
    if( id_str ) {
      m = id_str.match(/tabs=([-| \w]+)/);
      if( m ) {
        z = m[1].split(/\|/);
        for(i in z) {
          if(z.hasOwnProperty(i)) {
            hash_details = z[i].split(/ +/);
            hash = hash_details.shift();
            fire_tabs( z[i], hash_details );
          }
        }
        return;
      }
      if( id_str.match(/^#[- \w]+$/) ) {
        hash_details = id_str.split(/ +/);
        hash = hash_details.shift();
        fire_tabs( hash, hash_details );
      }
    }
  };

  $(function(){ Pagesmith.on_page_load_hash(); });

  $(document).on('click', '.change-tab', function () {
    var hash_details = $(this).prop('hash').split(/ +/),
        hash = hash_details.shift();
    fire_tabs( hash, hash_details );
    var id_sel = ' > li > a[href='+ hash +']',
        Z      = $('.tabs' + id_sel + ', .fake-tabs ' + id_sel);
    Pagesmith.update_tab_list( Z );
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
