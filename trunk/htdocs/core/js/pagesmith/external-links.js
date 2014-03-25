(function($){
  'use strict';
  /*----------------------------------------------------------------------
    External link code
  ------------------------------------------------------------------------
    For any link tagged with rel="external" add target = "_blank" to
    open the image up in a new tab/window.
  ----------------------------------------------------------------------*/
  (function ($) {
    $.fn.external_links = function () {
      return this.attr('target', '_blank');
    };
  }(jQuery));

  (function ($) {
    $.fn.add_class_to_last_char = function (cls) {
      if( this.attr('show') !== undefined ) {
        return '';
      }
      return this.html(function (i, html) {
        /*jslint regexp: true */
        var out = html.replace(/([^>\s]+)((\s*<\/\w+>)*\s*)$/, '<span class="' + cls + '">$1<img src="/core/gfx/blank.gif" /></span>$2');
        /*jslint regexp: false */
        return out;
      });
    };
  }(jQuery));

  function ext_links(T) {
    var //T   = $(this),
        H   = T.attr('href'),
        msg = 'This link opens in a new window',
        link_class,
        m1,
        m2;
    if (H && T.attr('target') !== '_blank' && T.attr('rel') !== 'no-external') {
      if (T.parents('h1,h2,h3,h4,.no-ext-images,.areas-landing').length) {
        T.addClass('no-img');
      }
      if (H.match(/\.pdf$/) || T.hasClass('pdf-link')) {
        T.external_links();
        if (!T.hasClass('no-img')) {
          T.add_class_to_last_char('pdf');
        }
      } else if (T.attr('rel') === 'external' || H.match(/^(ftp|https?):\/\//i)) {
        link_class = 'external';
        if (T.attr('rel') !== 'external') {
          /*jslint regexp: true */
          m1 = H.match(/^((ftp|https?):\/\/.*?)\//i);
          if (!m1) {
            m1 = H.match(/^((ftp|https?):\/\/.*?)$/i);
          }
          m2 = window.location.href.match(/^(https?:\/\/.*?)\//i);
          /*jslint regexp: false */
          if (m1[2] === 'ftp') {
            link_class = 'extftp';
          }
          if (m1 && m2 && m1[1].toLowerCase() === m2[1].toLowerCase()) {
            return;
          }
        }
        if (T.attr('title')) {
          T.attr('title', T.attr('title') + ' [' + msg + ']');
        } else {
          T.attr('title', '* ' + msg);
        }

        T.external_links();
        if (!T.hasClass('no-img')) {
          T.add_class_to_last_char(link_class);
        }
      }
    }
  }
  Pagesmith.On.load('a',function(){ ext_links($(this)); });
}(jQuery));
