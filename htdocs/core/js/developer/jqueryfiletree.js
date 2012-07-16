/*globals escape: true */
// jQuery File Tree Plugin
//
// Version 1.01
//
// Cory S.N. LaViska
// A Beautiful Site (http://abeautifulsite.net/)
// 24 March 2008
//
// Visit http://abeautifulsite.net/notebook.php?article=58 for more information
//
// Usage: $('.fileTreeDemo').fileTree( options, callback )
//
// Options:  root           - root folder to display; default = /
//           script         - location of the serverside AJAX file to use; default = jqueryFileTree.php
//           folderEvent    - event to trigger expand/collapse; default = click
//           expandSpeed    - default = 500 (ms); use -1 for no animation
//           collapseSpeed  - default = 500 (ms); use -1 for no animation
//           expandEasing   - easing function to use on expand (optional)
//           collapseEasing - easing function to use on collapse (optional)
//           multiFolder    - whether or not to limit the browser to one subfolder at a time
//           loadMessage    - Message to display while initial tree loads (can be HTML)
//
// History:
//
// 1.01 - updated to work with foreign characters in directory/file names (12 April 2008)
// 1.00 - released (24 March 2008)
//
// TERMS OF USE
//
// This plugin is dual-licensed under the GNU General Public License and the MIT License and
// is copyright 2008 A Beautiful Site, LLC.
//
(function ($) {
  $.extend($.fn, {
    fileTree: function (o, h) {
      // Defaults
      if (!o) {
        o = {};
      }
      if (o.root === undefined) {
        o.root = '/';
      }
      if (o.script === undefined) {
        o.script = '/action/jft';
      }
      if (o.folderEvent === undefined) {
        o.folderEvent = 'click';
      }
      if (o.multiFolder === undefined) {
        o.multiFolder = true;
      }
      if (o.loadMessage === undefined) {
        o.loadMessage = 'Loading...';
      }
      $(this).each(function () {

        function showTree(c, t) {
          $(c).addClass('wait');
          $(".jqueryFileTree.start").remove();
          $.post(o.script, { dir: t }, function (data) {
            $(c).find('.start').html('');
            $(c).removeClass('wait').append(data);
            if (o.root === t) {
              $(c).find('ul:hidden').show();
            } else {
              $(c).find('ul:hidden').show();
            }
            /*jslint undef: true */
            bindTree(c);
            /*jslint undef: false */
          });
        }

        function bindTree(t) {
          $(t).find('li a').bind(o.folderEvent, function () {
            if ($(this).parent().hasClass('dir')) {
              if ($(this).parent().hasClass('coll')) {
                // Expand
                if (!o.multiFolder) {
                  $(this).parent().parent().find('ul').hide();
                  $(this).parent().parent().find('li.dir').removeClass('exp').addClass('coll');
                }
                $(this).parent().find('ul').remove(); // cleanup
                showTree($(this).parent(), escape($(this).attr('rel')));
                $(this).parent().removeClass('coll').addClass('exp');
              } else {
                // Collapse
                $(this).parent().find('ul').hide();
                $(this).parent().removeClass('exp').addClass('coll');
              }
            } else {
              h($(this).attr('rel'));
            }
            return false;
          });
          // Prevent A from triggering the # on non-click events
          if (o.folderEvent.toLowerCase !== 'click') {
            $(t).find('li a').bind('click', function () { return false; });
          }
        }
        // Loading message
        $(this).html('<ul class="jft start"><li class="wait">' + o.loadMessage + '<li></ul>');
        // Get the initial file list
        showTree($(this), escape(o.root));
      });
    }
  });

}(jQuery));

$(document).ready(function () {
  var domain = window.location.protocol + '//' + window.location.hostname + '/';
  $('#jQueryFileTree').fileTree({multiFolder: true}, function (file) {
    $('#jQueryFileTop').html('<h4>/' + escape(file) + '</h4>').load('/action/Jft?dir=' + encodeURI(file));
    document.getElementById('pg').src = domain + file;
  });
  $('#jQueryFileBox').html('<iframe style="width:824px;height:700px" name="pg" id="pg"></iframe>');
});

