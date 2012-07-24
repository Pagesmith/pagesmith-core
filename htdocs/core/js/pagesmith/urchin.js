/**
 * Page initializer for the tracking cookie.  Call the urchinTracker main
 * code to generate the __utm.gif in the page, and consequently the
 * tracking cookies
 *
 * @author:   js5 (James Smith)
 * @version:  $Id$
 * @requires: urchin.js
 */

PageSmith.urchin = {
  init: function () {
    /*jsl:ignore*/
    if (Cookie.get('DNT') !== '1') {
      urchinTracker();
    }
    /*jsl:end*/
  }
};

$(function () { PageSmith.urchin.init(); } );
