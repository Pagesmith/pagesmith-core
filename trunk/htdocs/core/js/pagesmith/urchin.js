/* globals Cookie: true, urchinTracker: true */
/**
 * Page initializer for the tracking cookie.  Call the urchinTracker main
 * code to generate the __utm.gif in the page, and consequently the
 * tracking cookies
 *
 * @author:   js5 (James Smith)
 * @version:  $Id$
 * @requires: urchin.js
 */
(function(){
  'use strict';
  Pagesmith.urchin = {
    init: function () {
      if (Cookie.get('DNT') !== '1') {
        window.setTimeout( urchinTracker, 10 );
      }
    }
  };

  $(function () {
    Pagesmith.urchin.init();
  } );
}());
