/*----------------------------------------------------------------------
  AJAX autoloader

  author: js5 (James Smith)
  svn-id: $Id$
------------------------------------------------------------------------
  Looks for elements of class "ajax" and replaces content with the
  contents of the URL at their title...
----------------------------------------------------------------------*/



PageSmith.ajax = {
  can: function () {
    return PageSmith.flags.a === 'e';
  },
  autoload: function (x) {
    var url = x.attr('title'), m, d;
    if (x.hasClass('nocache')) {
      d = new Date();
      url += (url.match(/\?/) ? ';' : '?') + '__=' + d.getTime();
    }
    if (url.length > 2048) {
      /*jslint regexp: true */
      m = url.match(/^([^\?]+)\?(.*)$/);
      /*jslint regexp: false */
      if (m) {
      // Length is long! and can be split into URL & querystring
        $.post(m[1], m[2], function (data, status) {
          x.replaceWith(data).attr('title', 'Additional content loaded');
        });
      } else {
        $.get(url, '', function (data, status) {
          x.replaceWith(data).attr('title', 'Additional content loaded');
        });
      }
    } else {
      $.get(url, '', function (data, status) {
        x.replaceWith(data).attr('title', 'Additional content loaded');
      });
    }
    x.attr('title', 'Loading additional content').removeClass('ajax');
    return 0;
  },
  init: function () {
    if (!PageSmith.flags.a || !PageSmith.flags.a.match(/^[edn]$/)) {
      PageSmith.flags.a = ($.ajaxSettings.xhr() || false) ? 'e' : 'n';
      PageSmith.setCookie();
    }
    if (PageSmith.flags.a === 'e') {
      $('.ajax:visible').livequery(function () {
        if ($(this).hasClass('onclick')) {
          $(this).click(function () {
            PageSmith.ajax.autoload($(this));
          });
        } else {
          PageSmith.ajax.autoload($(this));
        }
      });
      $('.refreshable:visible').livequery(function () {
        var delay = 2000, match = $(this).attr('class').match(/delay_(\d+)/), p = this, to = 0;
        if (match) {
          delay = match[1];
        }
        $(this).append('<p class="r countdown" >Reloading in <span>' + Math.floor(delay / 1000) + '</span> seconds</p>');
        if ($(this).hasClass('countdown_timer')) {
          to = window.setInterval(function () {
            var n = $(p).find('.countdown').last(), s = parseInt(n.find('span').html(), 10) - 1;
            $(n).replaceWith('<p class="r countdown" >Reloading in <span>' + s + '</span> seconds</p>');
          }, 1000);
        }
        window.setTimeout(function () {
          var n = $(p).find('.countdown').last();
          $(n).replaceWith('<p class="r countdown" >Reloading now</p>');
          if (to) {
            window.clearInterval(to);
          }
          $(p).addClass('ajax');
        }, delay);
      });
    }
  }
};

PageSmith.ajax.init();
