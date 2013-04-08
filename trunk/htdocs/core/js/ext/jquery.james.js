/*
 * jQuery
 * version: 1.0 (2008/11/13)
 * @requires: jQuery v1.2.6
 * @uses: jQuery v1.9.1
 * @todo: Test it with previous jQuery versions
 * @author: sebastien rannou - http://www.aimxhaisse.com
 * @modified: james smith - http://www.sanger.ac.uk/
 *
 * Heavily modified version of James to add extra functionality
 *
 * Can now deal with embedded data - or a single AJAX request to get all possible values!
 *
 * Has ability to store "multiple" values from the list in "facebook-stylee"...
 *
 * licensed under the MIT: http://www.opensource.org/licenses/mit-license.php
 *
 * Revision: 1.js5.0
 *
 ** User Documentation
 ** ==================
 **
 ** Using javascript to configure:
 **
 ** HTML:
 **
 **     <input type="text" autocomplete="off" name="xx" id="xx" />
 **
 ** JavaScript:
 **
 **     $('#xx').james( '/autocomplete/URL', {} );
 **
 ** Using auto-configuration using $.metadata:
 **
 **     <input type="text" class="james {...} ..." autocomplete="off" name="xx" id="xx" />
 **
 ** Entries in the {} include:
 **
 ** * varname    - name of variable to pass in URL
 ** * url        - ajax request URL [not in JavaScript version]
 ** * params     - additional parameters
 ** * minlength  - Minimum length of value before AJAX request is mande!
 ** * filter     - If start/match then filter in Javascript - not if no source/data is set a single
 **                Ajax request is made which retrieves all possible values..
 ** * source     - string - ID of "UL" element containing values
 ** * data       - []  - Array of possible values (rather than getting via ajax)
 ** * multiple   - 0/1 - Allows mul
 ** * restricted - 0/1 - Only entries in the drop down list are allowed!
 ** * keydelay   - Length in delay between pressing key and sending ajax request (in milliseconds)
 **
 ** Pagesmith forms and auto-complete... (IE7 issues!)
 ** ==================================================
 **
 ** The CSS for the form code uses dl/dt/dd's to represent the form elements - in IE we had to mess
 ** around with margins to get this work (double margin bug in IE) so you will always need to put
 ** a "div" inside the <dd></dd> to get the auto-complete to work...
 **
 **     <dd><div><input ...></div></dd>
 **
 ** Multiple values...
 ** ==================
 **
 ** If you enable multiple values the input element must be embedded in a div of class
 ** "multi_container"
 **
 ** This is so the "facebook" like creation of "buttons" needs to have a specifc class
 **
 ** To pre-populate the form with multiple values you can manually add these "buttons" with
 ** the markup:
 **
 **     <span title="Click to remove" class="close_box">Value<input name=".." value=".." type="hidden" /></span>
 **
 ** within the "multi_container" div..
 **
 **     <div class="multi_container">
 **       <input type="text" class="james.... />
 **       <span title="Click to remove" class="close_box">XX<input name=".." value=".." type="hidden" /></span>
 **       <span title="Click to remove" class="close_box">XX<input name=".." value=".." type="hidden" /></span>
 **       <span title="Click to remove" class="close_box">XX<input name=".." value=".." type="hidden" /></span>
 **     </div>
 **
 ** Supplying data for javascript "filtering"
 ** =========================================
 **
 ** Data for javascript filtering can be pushed in three ways:
 **
 ** * "url" - retrieving via AJAX (no parameter is passed to ajax call)
 ** * "data" - embedded in options hash (either using metadata or via javascript) - good for "shortish" lists
 ** * "source" - embedded in a hidden "ul"
 **
 ** AJAX request set up!
 ** ====================
 **
 ** AJAX returns either an array of strings of an array of hashes
 **
 **     {text:"..",json:{}}
 **
 */

jQuery.fn.james = function (url_to_call, options) {
  var that = jQuery(this),
  results_set = [],
  current_hovered_rank = 0,
  no_of_entries = 0,
  keyEvents = [
    {keycode: 38, action: function () { keyEventKeyUp();   }}, // Up key
    {keycode: 39, action: function () { keyEventEnter();   }}, // right and ...
    {keycode: 13, action: function () { keyEventEnter();   }}, // ... enter both treated as enter
    {keycode: 40, action: function () { keyEventKeyDown(); }}, // Down key
    {keycode: 9,  action: function () { keyEventTab();     }}, // Tab key - select if in list!
    {keycode: 27, action: function () { keyEventEsc();     }}  // Escape key - clear...
  ],
  ul_element    = false,
  o = jQuery.extend({
    onKeystroke:  function (data) { return data; },
    onSelect:     function (dom_value, json_obj) { return $.trim(dom_value); },
    onSelectMultiple: function(dom_value, json_obj) {
      dom_value = $.trim(dom_value);
      if( dom_value && ! that.parent().find('span.close_box').filter(function(){ return $(this).text() === dom_value; }).length ) {
        that.parent().append(' <span title="Click to remove" class="close_box">'+dom_value+'<input name="'+that.attr('name')+'" value="'+dom_value+'" type="hidden" /></span>');
        that.attr("value",'');
      }
    },
    source:       false, // Source element (entries encoded in hidden embedded ul)
    data:         false, // List of all entries in drop-down!
    keydelay:     300,
    blurdelay:    2000,
    max_entries:  10,
    minlength:    3,
    restricted:   false, //
    multivalue:   false,
    method:       'get',
    varname:      'input_content',
    params:       ''
  }, options || {});


  // This method performs DOM initialization
  // Creates a UL with an Unique ID and push it to DOM
  // ** It's called only once
  (function initDOM() {
    var ul_id = false;
    var ul_node = document.createElement("ul");

    // Performs generation of an unique ID
    var genUniqueId = function () {
      var result = "ul_james_" + Math.round(Math.random() * 424242);
      if (jQuery("#" + result).length > 0) { result = genUniqueId(); }
      return result;
    };

    ul_id = genUniqueId();

    jQuery(ul_node).attr("id", ul_id).addClass("ul_james");
    that.after(ul_node);
    ul_element = jQuery("#" + ul_id); // Creating a shortcut
    ul_element.hide();
  })();

  // This method performs CSS initialization
  // It sets position's <ul> (especially for IE6) and sets result's width to input's width
  // Because offset can be changed, it's called each time
  // the dom is modified

  var initCSS = function initCSS() {
    var input_offset = that.position();
    var offset = 0;
    ul_element.css({
      top:    input_offset.top + that.outerHeight(),
      width:  that.outerWidth(),
      left:   input_offset.left,
      position:   "absolute"
    });
  };

  // This is used to avoid form to be submit when the user press Enter to make his choice
  // @TODO: When user has already made his choice, submit it

  that.keydown(function (event) {
    var l = ul_element.find(':visible').length;
    if( event.keyCode === 13 || event.keyCode === 9 ) {
      if( l || (o.restricted || o.multiple)  && $(this).attr('value')!=='' ) {
        event.preventDefault();
        return true;
      }
    }
  });

  // This method performs Keyboard Events
  // @TODO: Build actions for more key events (CTRL? ALT?) or recognize ASCII codes?

  var keyevent_current_timer = false;  // Timer's ID of next AJAX call
  var blur_current_timer = false;

  that.mouseenter(function(event) {
    if( blur_current_timer ) {
      window.clearTimeout( blur_current_timer );
      blur_current_timer = false;
    }
  });

  that.mouseleave(function(event) {
    blur_current_timer = window.setTimeout(function () {
      cleanResults();
    }, o.blurdelay);
  });

  that.keyup(function(event) {
    var is_specific_action = false, value_to_send;
    // Check if a specific action is linked to the keycode
    for (var i = 0; keyEvents[i]; i++) {
      if (event.keyCode === keyEvents[i].keycode) {
        is_specific_action = true;
        if( keyEvents[i].action() ) {
          event.preventDefault();
        }
        break;
      }
    }
    // If it's not a specific action
    if (is_specific_action === false) {
      // Unset last timeout if it was defined
      if (keyevent_current_timer !== false) {
        window.clearTimeout(keyevent_current_timer);
        keyevent_current_timer = false;
      }
      if(o.filter && (o.source || o.data) ) {
        results_set = [];
        value_to_send = that.prop("value").toLowerCase();
        if( current_hovered_rank <= 0 ) {
          current_hovered_rank = 0;
        }
        if( value_to_send.length > 0 ) {
          if( o.data ) {
            $.each( o.data, function(i,v) {
              if( o.filter === 'start' && (v.toLowerCase().indexOf( value_to_send ) === 0) ||
                  o.filter !== 'start' && (v.toLowerCase().indexOf( value_to_send ) > -1) ) {
                results_set.push({text:v,json:{}});
              }
            });
          } else { // Data in "source" ul - grab values - store in .data blow away ul. - now
                   // will go into above if block next time a key is pressed!
            o.data = [];
            $.each( $('#'+o.source+' li'), function(i,v) {
              var val = $(v).text();
              o.data.push(val);
              if( o.filter === 'start' && (val.toLowerCase().indexOf( value_to_send ) === 0) ||
                  o.filter !== 'start' && (val.toLowerCase().indexOf( value_to_send ) > -1) ) {
                results_set.push({text:val,json:{}});
              }
            });
            $('#'+o.source).remove();
          }
          updateDom();
        } else {
          cleanResults();
        }
      } else {
        // Set a now timeout with an AJAX call inside
        keyevent_current_timer = window.setTimeout(function () {
          ajaxUpdate();
        }, o.keydelay);
      }
    }
  });

  // This method performs AJAX calls
  var ajaxUpdate = function () {
    var value_to_send = that.prop("value");
    // Check length of input's value
    if( value_to_send.length > 0 && (o.minlength === false || value_to_send.length >= o.minlength)) {
      var qs = ($.isFunction(o.params)?o.params():o.params);
      if( !o.filter ) {
        qs = o.varname + "=" + value_to_send + "&" + qs;
      }
      $.ajax({
        type:     o.method,
        data:     qs,
        url:      url_to_call,
        dataType:   "json",
        success:  function (data) {
          var arr = o.onKeystroke(data),_json,_txt;
          results_set = [];
          if( o.filter ) { // Parse response - grab values - store in .data - now
                           // will go into o.data block above on next key press
            value_to_send = value_to_send.toLowerCase();
            o.data = [];
            for (var i in arr) {
              if (arr[i] !== null) {
                if (typeof(arr[i].json) === "undefined") {
                  _json = {};
                  _txt  = arr[i];
                } else {
                  _json = arr[i].json;
                  _txt  = arr[i].text;
                }
                o.data.push( _txt );
                if( o.filter === 'start' && (_txt.toLowerCase().indexOf( value_to_send ) === 0) ||
                    o.filter !== 'start' && (_txt.toLowerCase().indexOf( value_to_send ) > -1) ) {
                  results_set.push({text: _txt, json: _json});
                }
              }
            }
          } else {
            for (var ii in arr) {
              if (arr[ii] !== null) {
                if (typeof(arr[ii].json) === "undefined") {
                  results_set.push({text: arr[ii], json: {}});
                } else {
                  results_set.push({text: arr[ii].text, json: arr[ii].json});
                }
              }
            }
          }
          if( current_hovered_rank <= 0 ) {
            current_hovered_rank = 0;
          }
          updateDom();
        }
      });
    } else {
      cleanResults();
    }
  };

  /*
   * This method performs the display of the results set
   * Basically called when an event has been made
   */
  var updateDom = function () {
    jQuery(ul_element).empty();
    no_of_entries = 0;
    initCSS();
    for (var i in results_set) {
      if (results_set[i] !== null) {
        var li_elem = document.createElement("li");
        jQuery(li_elem).addClass("li_james");
        if (i == current_hovered_rank) {
          jQuery(li_elem).addClass("li_james_hovered");
        }
        jQuery(li_elem).append(results_set[i].text);
        jQuery(ul_element).append(li_elem);
        bind_elem_mouse_hover(li_elem, i);
        no_of_entries ++;
        if( no_of_entries >= o.max_entries) {
          break;
        }
      }
    }
    if (no_of_entries) {
      jQuery(ul_element).show();
      ul_element.mouseenter(function(event) {
        if( blur_current_timer ) {
          window.clearTimeout( blur_current_timer );
          blur_current_timer = false;
        }
      });
      ul_element.mouseleave(function(event) {
        blur_current_timer = window.setTimeout(function () {
          cleanResults();
        }, o.blurdelay);
      });
    } else {
      jQuery(ul_element).hide();
    }
  };

  /*
   * This method performs the ability to
   * select a result with mouse
   */
  var bind_elem_mouse_hover = function (elem, i) {
    jQuery(elem).hover(function() {
      jQuery(ul_element).find(".li_james_hovered").removeClass("li_james_hovered");
      jQuery(elem).addClass("li_james_hovered");
      current_hovered_rank = i;
    }, function() {
      jQuery(elem).removeClass("li_james_hovered");
      current_hovered_rank = 0;
    });
    jQuery(elem).click(function() {
      keyEventEnter(); // Treat this as a click event on the element!
    });
  };

  /*
   * This method clears results in DOM & JS
   */
  var cleanResults = function () {
    jQuery(ul_element).empty();
    jQuery(ul_element).hide();
    results_set = [];
    current_hovered_rank = 0;
  };

  /*
   * Key event actions
   */

  // Moving up into results set
  var keyEventKeyUp = function () {
    if (current_hovered_rank > (o.restricted ? 0 : -1) ) {
      current_hovered_rank--;
    } else if (no_of_entries) {
      current_hovered_rank = no_of_entries - 1;
    }
    updateDom();
  };

  // Moving down into resuls set
  var keyEventKeyDown = function () {
    if (current_hovered_rank < (no_of_entries - 1)) {
      current_hovered_rank++;
    } else {
      current_hovered_rank = 0;
    }
    updateDom();
  };

  // Selecting a set (onSelect function is called there)
  var keyEventEnter = function () {
    if (results_set.length > 0 && current_hovered_rank >= 0 ) {
      if( o.multiple ) {
        that.attr("value", o.onSelectMultiple( results_set[current_hovered_rank].text, results_set[current_hovered_rank].json, that ) );
      } else {
        that.attr("value", o.onSelect(         results_set[current_hovered_rank].text, results_set[current_hovered_rank].json, that ) );
      }
    } else { // What to do when we are in the input element itself!
      if( !o.restricted ) {
        if( o.multiple ) {
          that.attr("value", o.onSelectMultiple( that.attr("value"), {}, that ) );
        } else {
          that.attr("value", o.onSelect(         that.attr("value"), {}, that ) );
        }
      }
    }
    cleanResults();
    return 1; // This means we will run preventDefault..!
  };
  // Selecting a set (onSelect function is called there)
  var keyEventTab = function () {
    var return_value = 0;
    if (results_set.length > 0 && current_hovered_rank >= 0 ) {
      if( o.multiple ) {
        that.attr("value", o.onSelectMultiple( results_set[current_hovered_rank].text, results_set[current_hovered_rank].json, that ) );
      } else {
        that.attr("value", o.onSelect(         results_set[current_hovered_rank].text, results_set[current_hovered_rank].json, that ) );
      }
      return_value = 1;
    } else { // What to do when we are in the input element itself!
      if( !o.restricted ) {
        if( o.multiple ) {
          that.attr("value", o.onSelectMultiple( that.attr("value"), {}, that ) );
          return_value = 1;
        } else {
          that.attr("value", o.onSelect(         that.attr("value"), {}, that ) );
          return_value = 0;
        }
      } else {
        return_value = 1;
      }
    }
    cleanResults();
    return return_value; // This means we will run preventDefault..!
  };

  // Removing results set
  var keyEventEsc = function () {
    that.attr("value", "");
    cleanResults();
  };
};

// The following is a livequery james auto-loader! - requires metadata so that it can get the information from the class
// example <input id="XX" name="XX" class="james {url:'/action/Auto', varname:'XX', minlength:2}" value="XX" autocomplete="off" />
if($.metadata){
  $('.james').livequery(function(){ var md = $(this).metadata(); $(this).james(md.url, md); });
}
/* Multi-select... */
$('body').on('click','.close_box',function() { $(this).remove(); });

