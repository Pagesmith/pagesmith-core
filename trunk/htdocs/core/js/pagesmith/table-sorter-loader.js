(function($){
  'use strict';
  /*----------------------------------------------------------------------
    Table sorter code

    author: js5 (James Smith)
    svn-id: $Id$
  ------------------------------------------------------------------------
    Dependency: jquery.tablesorter.200.js, jquery.livequery.js
  ------------------------------------------------------------------------
    Attach the table sorter code to all tables that are marked with
    ".sorted-table" class
  ----------------------------------------------------------------------*/

  var table_counter = 0;

  function sort_obj(obj){
    var s_keys = [], s_obj = {};
    $.each(obj,function(k) { s_keys.push(k); }); /* jsxhint ignore:line */
    s_keys.sort();
    $.each(s_keys,function(i,k){s_obj[k] = obj[k];});
    return s_obj;
  }

  $('body').first().append('<form action="/action/ExportJsonTable" method="post" id="export_json_table">'+
   '<input type="hidden" value="" name="json" id="table_json"/><input type="hidden" value="" name="summary" id="table_summary"/>'+
   '<input type="hidden" value="" name="filter" id="table_filter"/></form>');

  /* jshint -W074 */
  $('.sorted-table').livequery(function () { // Make "sorted-table"s sortable
    // console.log( $(this).html().substr(0,200) ); // useful to debug errors!
    $(this).tablesorter({ parserMetadataName:'sv', widgets: ['zebra']});
    table_counter++;
    var class_string = $(this).attr('class'),
      table_key = 'table_' + table_counter,
      form_el,
      m = $(this).attr('class').match(/\bpaginate_(\w+)/),
      sizes,
      t_array,
      sel,
      si,
      size_value,
      size_text,
      exports,
      selected,
      formats,
      fo,
      q,
      cols,
      x,
      filter_values,
      s,
      j,
      md = $.metadata && $(this).metadata() ? $(this).metadata() : {},
      refresh_url = '',
      export_url = '',
      entries = '',
      my_cells;

    if( md ) {
      if( md.refresh ) {
        refresh_url = md.refresh;
      }
      if( md.entries ) {
        entries = md.entries;
      }
      if( md['export'] ) {
        export_url = md['export'];
      }
    }

    if ($(this).hasClass('before')) {
      $(this).before('<div id="' + table_key + '" class="pager"><form></form></div>');
    } else {
      $(this).after('<div id="' + table_key + '" class="pager"><form></form></div>');
    }
    form_el= $('#' + table_key + ' form');

    // Include a filter ?
    if ($(this).hasClass('filter')) {
      form_el.append('<span>Filter: <input type="text" value="" class="filter" /> ');
    }

    // Include pagination dropdown ?
    if (m) {
      form_el.append('<span class="pagedisplay" />');
      if (!m[1].match(/x/)) {
        m[1] = 'x' + m[1];
      }
      sizes = m[1].split('_');
      if (sizes.length === 1) {
        size_value = sizes[0].substr(1);
        if (size_value === 'all') {
          size_value = 1000000;
        }
        form_el.append('<input type="hidden" class="pagesize" value="' + size_value+ '" >');
      } else {
        sel = '<select class="pagesize">';
        for (si = 0; si < sizes.length; si++) {
          size_value = sizes[si];
          selected = '';
          if (size_value.substr(0, 1) === 'x') {
            size_value = size_value.substr(1);
            selected = ' selected="selected"';
          }
          size_text = size_value + ' per page';
          if (size_value === 'all') {
            size_value = 1000000;
            size_text  = 'All';
          }
          sel += '<option' + selected + ' value="' + size_value + '">' + size_text + '</option>';
        }
        form_el.append(sel + '</select>');
      }

    }

    // Include export links ?
    m = class_string.match(/\bexport_(\w+)/);
    if (m) {
      exports = '<span>';
      formats = m[1].split('_');
      for (fo = 0; fo < formats.length; fo++) {
        exports += '<span class="jsondump">' + formats[fo].toUpperCase() + '</span>';
      }
      form_el.append(exports + '</span>');
    }

    // Add Functionality to table
    if ($(this).hasClass('colfilter')) {
      my_cells = $(this).find('thead th');
      if ($(this).hasClass('before')) {
        $(this).find('thead').first().after('<thead></thead>');
        q = $(this).find('thead').eq(1);
      } else {
        q = $(this).find('.foot');
        if (q.length < 1) {
          $(this).append('<tbody class="foot"></tbody>');
          q = $(this).find('.foot');
        }
      }
      cols = 0;
      $(this).find('tr').each(function () {
        x = this.cells.length;
        if (x > cols) {
          cols = x;
        }
      });
      t_array = [];
      for (j=cols; j; j) {
        j--;
        if( $.metadata && my_cells.eq(j).metadata() && my_cells.eq(j).metadata().filter ) {
          filter_values = my_cells.eq(j).metadata().filter;
          if( filter_values instanceof Array ) {
            t_array.unshift( '<td class="c"><select class="colfilter"><option value="">==</option><option>'+
              filter_values.join('</option><option>')+'</option></select></td>' );
          } else {
            s = '<td class="c"><select class="colfilter"><option value="">==';
            var X = sort_obj(filter_values),ky;
            for(ky in X) {
              if( X.hasOwnProperty(ky) ) {
                s+= '</option><option value="'+Pagesmith.escapeHTML(ky)+'">'+Pagesmith.escapeHTML(ky)+' ('+Pagesmith.escapeHTML(X[ky])+')';
              }
            }
            s += '</option></select></td>';
            t_array.unshift( s );
          }
        } else if( $.metadata && my_cells.eq(j).metadata() && my_cells.eq(j).metadata().no_filter ) {
          t_array.unshift( '<td class="c"><input class="colfilter" type="hidden" />&nbsp;</td>' );
        } else {
          t_array.unshift( '<td class="c"><input style="width:95%; margin: 2px 0" class="colfilter" type="text" /></td>' );
        }
      }
      q.first().append('<tr>' + t_array.join('') + '</tr>');
    }
    $(this).tablesorterPager({
      container: $('#' + table_key),
      refresh_url:    refresh_url,
      entries:        entries,
      export_url:     export_url
    });
  });
  /* jshint +W074 */
  jQuery.fn.zebra = function () {
    /* If there is no "thead" block then flip the colours grey/white rather
      that white/grey so the first row is grey... */
    if (!jQuery(this).find('thead').length) {
      jQuery(this).addClass('flip');
    }
    /*jsl:ignore*/
    jQuery(this).find('tbody').not('.foot').children('tr')
      .filter(':even')
        .removeClass('odd')
        .addClass('even')
      .end()
      .filter(':odd')
        .removeClass('even')
        .addClass('odd');
    /*jsl:end*/
  };
  $('.zebra').livequery(function () {
    $(this).children('dt').first().siblings('dt').addClass('bordered').next().addClass('bordered');
  });
  $('.zebra-table').livequery(function () {
    if (!$(this).hasClass('faked')) {
      $(this).zebra();
    }
  });

  // Export for a zebra-table
  function plain_table_json_export(tb, format) {
    var t_data = { head: [], body: [] }, th = tb.tHead, i, r, row, j, tb1;
    if (th) {
      for (i = th.rows.length; i; i) {
        i--;
        row = th.rows[i].cells;
        r = [];
        for (j = row.length; j; j) {
          j--;
          r.unshift($.trim($(row[j]).text()));
        }
        t_data.head.unshift(r);
      }
    }
    if (tb.tBodies.length > 0) {
      tb1 = tb.tBodies[0];
      for (i = tb1.rows.length; i; i) {
        i--;
        row = tb1.rows[i];
        r = [];
        for (j = row.cells.length; j; j) {
          j--;
          r.unshift($.trim($(row.cells[j]).text()));
        }
        t_data.body.unshift(r);
      }
    }
    $('#table_json').val(JSON.stringify(t_data));
    $('#table_summary').val($(tb).attr('summary'));
    $('#table_filter').val('');
    $('#export_json_table').attr({target: '_blank', action: '/action/ExportJsonTable/' + format}).submit();
    return;
  }

  $('.exportable').livequery(function () {
    var that = this,
        table = $(this),
        m = $(this).attr('class').match(/\bexport_(\w+)/),
        form_el, table_key, exports, formats, fo;
    table_counter++;
    table_key = 'table_' + table_counter;
    if (table.hasClass('before')) {
      table.before('<div id="' + table_key + '" class="pager"></div>');
    } else {
      table.after('<div id="' + table_key + '" class="pager"></div>');
    }
    form_el = $('#' + table_key);

    if (m) {
      exports = '<span>';
      formats = m[1].split('_');
      for (fo = 0; fo < formats.length; fo++) {
        exports += '<span class="jsondump">' + formats[fo].toUpperCase() + '</span>';
      }
      form_el.append(exports + '</span>');
    }
    $('.jsondump', form_el).click(function () {
      plain_table_json_export(that, $(this).html());
      return false;
    });
  });

  (function ($) {
    $.fn.rotateTableCellContent = function () {
      if($(this).hasClass('headers_rotated')) {
        return;
      }
      var cellsToRotate = $('.rotated_cell', this), betterCells = [];
      cellsToRotate.each(function () {
        var cell        = $(this),
            newText     = $.trim(cell.text());
        cell.html( $('<span>').text(newText) );
        var SF          = 1,
            height      = cell.innerHeight(),
            width       = cell.find('span').innerWidth(),
            newDiv      = $('<div>').height( (width+10)*SF ).width( height*SF ).css('margin','0 auto'),
            newInnerDiv = $('<div>', { 'class': 'rotated' }).html(newText),
            t_string    = (width / 2 + 4 ) + 'px ' + ( 4 + width / 2) + 'px';
        newInnerDiv.css('-webkit-transform-origin', t_string );
        newInnerDiv.css('-moz-transform-origin',    t_string );
        newInnerDiv.css('-ms-transform-origin',     t_string );
        newInnerDiv.css('-o-transform-origin',      t_string );
        newDiv.append(newInnerDiv);
        newInnerDiv.css( $(this).css('background-color') );
        betterCells.push(newDiv);
      });
      cellsToRotate.each(function (i) {
        $(this).html(betterCells[i]);
      });
      cellsToRotate.each(function () {
        $(this).css({'padding-right':'4px','padding-left':'4px'});
      });
      $(this).addClass('headers_rotated');
    };
  })(jQuery);

  $('table:visible').livequery(function(){
    $(this).rotateTableCellContent();
  });
}(jQuery));
