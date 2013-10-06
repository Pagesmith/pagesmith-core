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
    var m, d,
        url       = x.attr('title'),
        ajax_pars = {type:'GET',url:url,data:'',dataType:'text'};

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
        ajax_pars.type = 'POST';
        ajax_pars.url  = m[1];
        ajax_pars.data = m[2];
      }
    }
    ajax_pars.success = function(data,status) {
      x.replaceWith(data);
      $(window).trigger('resize');
    };
    ajax_pars.error = function(xhr,status,message) {
      x.replaceWith('<p>Unable to load content</p>').prop('title',message);
    };
    $.ajax(ajax_pars);
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
        var delay = 2000, match = $(this).attr('class').match(/delay_(\d+)/), p = this, to = 0, pause_html, reloadto;
        if (match) {
          delay = match[1];
        }
        pause_html = '';
        if( delay && $(this).hasClass('pauseable') ) {
          pause_html += ' <span class="pause" title="running">||</span><span class="play hidden" title="paused">&#x25b6;</span>';
        }
        if( delay <= 0 || $(this).hasClass('forceable') ) {
          pause_html += ' <span class="refresh">Reload</span>';
        }
        if( delay > 0 ) {
          $(this).append('<p class="r countdown" >Reloading in <span class="timer">' + Math.floor(delay / 1000) + '</span> seconds'+ pause_html+'</p>');
          if ($(this).hasClass('countdown_timer')) {
            to = window.setInterval(function () {
              var n = $(p).find('.countdown').last(), s = parseInt(n.find('.timer').html(), 10) - 1;
              $(n).replaceWith('<p class="r countdown" >Reloading in <span class="timer">' + s + '</span> seconds'+pause_html+'</p>');
            }, 1000);
          }

          reloadto = window.setTimeout(function () {
            var n = $(p).find('.countdown').last();
            $(n).replaceWith('<p class="r countdown" >Reloading now</p>');
            if (to) {
              window.clearInterval(to);
            }
            $(  p).addClass('ajax');
          }, delay);
        } else {
          $(this).append('<p class="r countdown">'+pause_html+'</p>');
        }
        $(this).delegate('.pause','click', function(){
          $(this).addClass('hidden');
          $(p).find('.play').removeClass('hidden');
          if( to ) {
            window.clearInterval( to );
          }
          if( reloadto ) {
            window.clearTimeout( reloadto );
          }
        });
        $(this).delegate('.play','click',function(){
          var n = $(p).find('.countdown').last(), timer = $(p).find('.timer'), s = parseInt(n.find('.timer').html(), 10) - 1;
          $(this).addClass('hidden');
          $(p).find('.pause').removeClass('hidden');
          if( timer ) {
            if( $(p).hasClass('countdown_timer')) {
              to = window.setInterval(function () {
                var n = $(p).find('.countdown').last(), timer = $(p).find('.timer'), s = parseInt(n.find('.timer').html(), 10) - 1;
                $(n).replaceWith('<p class="r countdown" >Reloading in <span class="timer">' + s + '</span> seconds'+pause_html+'</p>');
              }, 1000);
            }
            reloadto = window.setTimeout(function () {
              $(n).replaceWith('<p class="r countdown" >Reloading now</p>');
              if (to) {
                window.clearInterval(to);
              }
              $(  p).addClass('ajax');
            }, (s+1)*1000);
          }
        });
        $(this).delegate('.refresh', 'click', function(){ $(p).addClass('ajax'); } );
      });
    }
  }
};

PageSmith.ajax.init();
