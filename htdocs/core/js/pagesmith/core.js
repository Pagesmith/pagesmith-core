var Pagesmith;
(function($){
  'use strict';
  /*globals escape, unescape */
  /*----------------------------------------------------------------------
    Core Pagesmith object
    author: js5 (James Smith)
    svn-id: $Id$
  ------------------------------------------------------------------------
    Page initializer

    In the first case just sets up the AJAX cookie so the server can
    no whether page content can be loaded via ajax!
  ----------------------------------------------------------------------*/

  var Cookie = {
    set: function (name, value, expiry) {
      document.cookie = escape(name) + '=' + escape(value || '') +
        '; expires=' + (expiry === -1 ? 'Thu, 01 Jan 1970' : 'Tue, 19 Jan 2038') +
        ' 00:00:00 GMT; path=/';
    },
    get: function (name) {
      if (typeof (document.cookie) !== 'undefined') {
        var cookie = document.cookie.match(new RegExp('(^|;)\\s*' + escape(name) + '=([^;\\s]*)'));
        return cookie ? unescape(cookie[2]) : '';
      }
      return '';
    }
  };

  Pagesmith = {
    cookie_name: 'Pagesmith',
    flags: {z: 'n'},
    setCookie: function () {
      Cookie.set(this.cookie_name, JSON.stringify(this.flags));
    },
    getCookie: function () {
      var json_string = Cookie.get(this.cookie_name), data_structure;
      if (json_string) {
        try {
          data_structure = JSON.parse(json_string);
          if (data_structure) {
            this.flags = data_structure;
          }
        } catch (e) {
        }
      }
    }
  };

  window.Cookie    = Cookie;
  window.Pagesmith = Pagesmith;
  Pagesmith.getCookie();

  // This little listener stops any link back to the current page from firing!

  $('body').on('click','a[href="'+document.location.pathname+document.location.search+'"]',function(e){
    if($(this).hasClass('follow')){
      return true;
    }
    e.preventDefault();
    return false;
  });

}(jQuery));
