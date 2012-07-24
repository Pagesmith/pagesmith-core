/*jsl:ignoreall*/
var CookieP = {
  get: function (name) {
    var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + escape(name) + '=([^;\\s]*)'));
    return cookie ? unescape(cookie[2]) : '';
  }
};

$(function() {
if( CookieP.get('DNT')!='1' ) { try {
  var piwikTracker = Piwik.getTracker( "/piwik.php", my_site_id );
  piwikTracker.trackPageView();
  piwikTracker.enableLinkTracking();
} catch( err ) {}
}
});
