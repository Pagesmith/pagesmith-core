(function($){
  'use strict';
/* Pagesmith.On
 * Extensions to allow pages to perform javascript on elements which are "loaded" into the
   page dynamically or made to appear. This is effectively a replacement for livequery - which
   is hopefully more efficient....

   Usage: - adding functions to elements.....

     Pagesmith.On.load( 'selector' , function(){

     }).show( 'selector' , function(){

     });

     * load( .... ) these are functions to be executed when the dom element is added to the page
     * show( .... ) these are functions to be executed when the dom element becomes visible


   Usage: - adding one or more classes that when (addClass/removeClass) is called will trigger
            checks for visibility changes... by default it doesn't perform this check - saves
            a lot of DOM parsing!

   Pagesmith.On.add_class( 'show-reference hide-reference' );

   Usage: - run attached functions on newly created HTML blob...

   dom_element.html( '<p>Put new HTML here</p>' );
   Pagesmith.On.flush( dom_element );

*/
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
    all_load:     function( fi, fn ) {
      this.load_methods.push( [fi, fn, 'all' ] );
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
    remove_class: function( cl ) {
      var i, t = cl.split(/\s+/);
      for( i in t ) {
        if( t.hasOwnProperty(i) && t[i] in this.show_classes ) {
          delete this.show_classes[ t[i] ];
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
            $.fn['__'+m] = old;
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
            $.fn['__'+m] = old;
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
    all_flush: function( ) {
      var i,x;
      for(i in this.load_methods) {
        if( this.load_methods.hasOwnProperty(i) ) {
          x = this.load_methods[i];
          if( x[2] && x[2] === 'all' ) {
            $(document).find(x[0]).add($(document).filter(x[0])).each(x[1]);
          }
        }
      }
      return this;
    },
    flush: function( node ) {
      var i,x;
      for(i in this.load_methods) {
        if( this.load_methods.hasOwnProperty(i) ) {
          x = this.load_methods[i];
          if( x[2] && x[2] === 'all' ) {
            $(document).find(x[0]).add($(document).filter(x[0])).each(x[1]);
          } else {
            $(node).find(x[0]).add($(node).filter(x[0])).each(x[1]);
          }
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
  // Standard pagesmith classes....
  Pagesmith.On.add_class('show tabc hide coll dev-toggle collapsed tabc_hid ref-closed');
  // Finally run the load init on page load!

  $(function(){Pagesmith.On.load_init();});

}(jQuery));
