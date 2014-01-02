/* globals define: true, require: true */
(function (factory) {
  'use strict';
  if (typeof define === 'function' && define.amd) {
    define(['jquery'], factory);
  } else if (typeof exports === 'object') {
    factory(require('jquery'));
  } else {
    factory(jQuery);
  }
}(function ($, undefined) {
  'use strict';
  function _match(me, query, fn, fn2) {
    return me.selector === query.selector &&
      me.context === query.context &&
      (!fn || fn.$lqguid === query.fn.$lqguid) &&
      (!fn2 || fn2.$lqguid === query.fn2.$lqguid);
  }

  $.extend($.fn, {
    livequery: function(fn, fn2) {
      var me = this, q;

      // See if Live Query already exists
      $.each( JQlq.queries, function(i, query) {
        if ( _match(me, query, fn, fn2) ) {
            // Found the query, exit the each loop
          return (q = query) && false;
        }
      });

      // Create new Live Query if it wasn't found
      q = q || new JQlq(me.selector, me.context, fn, fn2);

      // Make sure it is running
      q.stopped = false;

      // Run it immediately for the first time
      q.run();

      // Contnue the chain
      return me;
    },

    expire: function(fn, fn2) {
      var me = this;

      // Find the Live Query based on arguments and stop it
      $.each( JQlq.queries, function(i, query) {
        if ( _match(me, query, fn, fn2) && !me.stopped) {
          JQlq.stop(query.id);
        }
      });

      // Continue the chain
      return me;
    }
  });

  var JQlq = $.livequery = function(selector, context, fn, fn2) {
    var me = this;

    me.selector = selector;
    me.context  = context;
    me.fn       = fn;
    me.fn2      = fn2;
    me.elements = $([]);
    me.stopped  = false;

    // The id is the index of the Live Query in $.livequiery.queries
    me.id = JQlq.queries.push(me)-1;

    // Mark the functions for matching later on
    fn.$lqguid = fn.$lqguid || JQlq.guid++;
    if (fn2) {
      fn2.$lqguid = fn2.$lqguid || JQlq.guid++;
    }

    // Return the Live Query
    return me;
  };

  JQlq.prototype = {
    stop: function() {
      var me = this;
      // Short-circuit if stopped
      if ( me.stopped ) {
        return;
      }
      if (me.fn2) {
        // Call the second function for all matched elements
        me.elements.each(me.fn2);
      }
      // Clear out matched elements
      me.elements = $([]);

      // Stop the Live Query from running until restarted
      me.stopped = true;
    },

    run: function() {
      var me = this;
      // Short-circuit if stopped
      if ( me.stopped ) {
        return;
      }
      var oEls = me.elements,
        els  = $(me.selector, me.context),
        newEls = els.not(oEls),
        delEls = oEls.not(els);

      // Set elements to the latest set of matched elements
      me.elements = els;

      // Call the first function for newly matched elements
      newEls.each(me.fn);

      // Call the second function for elements no longer matched
      if ( me.fn2 ) {
        delEls.each(me.fn2);
      }
    }
  };

  $.extend(JQlq, {
    guid: 0,
    queries: [],
    queue: [],
    running: false,
    timeout: null,
    registered: [],

    checkQueue: function() {
      if ( JQlq.running && JQlq.queue.length ) {
        var length = JQlq.queue.length;
        // Run each Live Query currently in the queue
        while ( length-- ) {
          JQlq.queries[ JQlq.queue.shift() ].run();
        }
      }
    },

    pause: function() {
      // Don't run anymore Live Queries until restarted
      JQlq.running = false;
    },

    play: function() {
      // Restart Live Queries
      JQlq.running = true;
      // Request a run of the Live Queries
      JQlq.run();
    },

    registerPlugin: function() {
      $.each( arguments, function(i,n) {
        // Short-circuit if the method doesn't exist
        if (!$.fn[n] || $.inArray(n, JQlq.registered) > 0) {
          return;
        }
        // Save a reference to the original method
        var old = $.fn[n];

        // Create a new method
        $.fn[n] = function() {
          // Call the original method
          var r = old.apply(this, arguments);

          // Request a run of the Live Queries
          JQlq.run();

          // Return the original methods result
          return r;
        };

        JQlq.registered.push(n);
      });
    },

    run: function(id) {
      if (id !== undefined) {
        // Put the particular Live Query in the queue if it doesn't already exist
        if ( $.inArray(id, JQlq.queue) < 0 ) {
          JQlq.queue.push( id );
        }
      } else {
        // Put each Live Query in the queue if it doesn't already exist
        $.each( JQlq.queries, function(id) {
          if ( $.inArray(id, JQlq.queue) < 0 ) {
            JQlq.queue.push( id );
          }
        });
      }
      // Clear timeout if it already exists
      if (JQlq.timeout) {
        clearTimeout(JQlq.timeout);
      }
      // Create a timeout to check the queue and actually run the Live Queries
      JQlq.timeout = setTimeout(JQlq.checkQueue, 20);
    },

    stop: function(id) {
      if (id !== undefined) {
        // Stop are particular Live Query
        JQlq.queries[ id ].stop();
      } else {
        // Stop all Live Queries
        $.each( JQlq.queries, JQlq.prototype.stop);
      }
    }
  });

  // Register core DOM manipulation methods
  JQlq.registerPlugin('append', 'prepend', 'after', 'before', 'wrap', 'attr', 'removeAttr', 'addClass', 'removeClass', 'toggleClass', 'empty', 'remove', 'html', 'prop', 'removeProp');

  // Run Live Queries when the Document is ready
  $(function() { JQlq.play(); });

}));
