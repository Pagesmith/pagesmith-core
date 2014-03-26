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

  Pagesmith.On = {
    load_methods: [],
    show_methods: [],
    show_classes: {},
    loaded:  0,
    load:     function( fi, fn ) {
      this.load_methods.push( [fi, fn] );
      if( this.loaded ) {
        $(document).find(fi).each(fn);
      }
      return this;
    },
    add_class: function( cl ) {
      var i, t = cl.split(/\s+/);
      for( i in t ) {
        if( t.hasOwnProperty(i) ) {
          this.show_classes[ t[i] ] = 1;
        }
      }
      return this;
    },
    show: function( fi, fn ) {
      this.show_methods.push( [fi, fn] );
      // Apply method to all the objects in the page!
      if( this.loaded ) {
        $(document).find(fi).filter(':visible').each(fn);
      }
      return this;
    },
    load_init: function() {
      this.flush( document );
      this.loaded = 1;
      return this;
    },
    /* jshint -W083 */
    show_init: function() {
      var i, fns_show = ['show','hide'], fns_class = ['addClass','removeClass'], self = this;
      // Add method callers!
      for(i in fns_show) {
        if( fns_show.hasOwnProperty(i) ) {
          (function(){
            var m = fns_show[i];
            var old = $.fn[m];
            $.fn[m] = function() {
              var vo = $(this).find(':visible').add($(this).filter(':visible')),
                   r = old.apply( this, arguments ),
                  vn = $(this).find(':visible').add($(this).filter(':visible')),
                 shw = vn.not(vo),
                 /*hde = vo.not(vn),*/j, m2;
              if(shw.length>0) {
                for(j=self.show_methods.length;j;j) {
                  j--;
                  m2 = self.show_methods[j];
                  shw.filter(m2[0]).each(m2[1]);
                }
              }
              return r;
            };
          }());
        }
      }
      var k;
      for(k in fns_class) {
        if( fns_class.hasOwnProperty(k) ) {
          (function(){
            var m = fns_class[k];
            var old = $.fn[m];
            $.fn[m] = function() {
              var i,my_classes = arguments[0].split(/\s+/), flag = 0;
              for( i=my_classes.length;i;i) {
                i--;
                if( my_classes[i] in self.show_classes ) {
                  flag = 1;
                  break;
                }
              }
              if( flag === 0 ) {
                return old.apply( this, arguments );
              }
              var vo = $(this).find(':visible').add($(this).filter(':visible')),
                   r = old.apply( this, arguments ),
                  vn = $(this).find(':visible').add($(this).filter(':visible')),
                 shw = vn.not(vo),
                 /*hde = vo.not(vn),*/j, m2;
              if(shw.length>0) {
                for(j=self.show_methods.length;j;j) {
                  j--;
                  m2 = self.show_methods[j];
                  shw.filter(m2[0]).each(m2[1]);
                }
              }
              return r;
            };
          }());
        }
      }
    },
    /* jshint +W083 */
    flush: function( node ) {
      var i,x;
      for(i in this.load_methods) {
        if( this.load_methods.hasOwnProperty(i) ) {
          x = this.load_methods[i];
          $(node).find(x[0]).add($(node).filter(x[0])).each(x[1]);
        }
      }
      for(i in this.show_methods) {
        if( this.show_methods.hasOwnProperty(i) ) {
          x = this.show_methods[i];
          $(node).find(x[0]).add($(node).filter(x[0])).filter(':visible').each(x[1]);
        }
      }
      return this;
    }
  };
  Pagesmith.On.show_init(); // Fire this now as we have to define the dom methods!
  Pagesmith.On.add_class('show tabc hide coll dev-toggle collapsed tabc_hid ref-closed');
  $(function(){Pagesmith.On.load_init();});

  // This little listner stops any link back to the current page from working!

  $('body').on('click','a[href="'+document.location.pathname+document.location.search+'"]',function(e){
    if($(this).hasClass('follow')){
      return true;
    }
    e.preventDefault();
    return false;
  });

}(jQuery));
