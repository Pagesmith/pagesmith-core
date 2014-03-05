(function ($) {
  'use strict';
  $.extend({
    tablesorterPager: {
      // Include count!
      // Display links as 1 2 ... 7 8 9 ... n - 1 n
      updatePageDisplay: function (c, table) {
        var html = '', pn = 0;
        if (c.showCount) {
          html += c.totalRows;
          if (c.totalRows !== c.totalRowsRaw) {
            html += ' out of ' + c.totalRowsRaw;
          }
          html += ' entries ';
        }
        while (pn < c.totalPages) {
          if (pn < c.n_end || pn >= c.totalPages - c.n_end || (pn > c.page - c.n_pad - 1 && pn < c.page + c.n_pad + 1)) {
            html += pn === c.page ? '<strong>' + (pn + 1) + '</strong>' : '<span>' + (pn + 1) + '</span>';
          } else {
            html += '...';
            pn = pn < c.page ? c.page - c.n_pad - 1 : c.totalPages - c.n_end  - 1;
          }
          pn++;
        }
        $(c.cssPageDisplay, c.container).html(html);

        $(c.cssPageDisplay + ' span', c.container).click(function () {
          $.tablesorterPager.moveToLinkPage(table, $(this).html());
          return false;
        });
      },

      setPageSize: function (table, size) {
        var c = table.config;
        if (size === 0) {
          size = 100000000;
        }
        c.page = Math.floor(c.page * c.size / size);
        c.size = size;
        c.totalPages = Math.ceil(c.totalRows / c.size);
        c.pagerPositionSet = false;
        $.tablesorterPager.moveToPage(table);
        $.tablesorterPager.fixPosition(table);
      },

      fixPosition: function (table) {
        var c = table.config, o = $(table);
        if (!c.pagerPositionSet && c.positionFixed) {
          if (o.offset) {
            c.container.css({
              top: o.offset().top + o.height() + 'px',
              position: 'absolute'
            });
          }
          c.pagerPositionSet = true;
        }
      },

      moveToLinkPage: function (table, pid) {
        var c = table.config;
        c.page = pid - 1;
        if (c.page <= 0) {
          c.page = 0;
        }
        if (c.page >= (c.totalPages - 1)) {
          c.page = (c.totalPages - 1);
        }
        $.tablesorterPager.renderTable(table, c.rowsCopy);
      },

      moveToPage: function (table) {
        var c = table.config;
        if (c.page < 0 || c.page > (c.totalPages - 1)) {
          c.page = 0;
        }
        $.tablesorterPager.renderTable(table, c.rowsCopy);
      },

      get_json: function (table, format) {
        var c = table.config, table_data = { head: [],  body: [] }, th = table.tHead, i, row, r, j,cls,k;
        for (i = th.rows.length;  i; i) {
          i--;
          row = th.rows[i].cells;
          r = [];
          for (j = row.length; j; j) {
            j--;
            cls = $(row[j]).prop('colspan');
            if( cls > 1 ) {
              for (k = cls-1;k;k){
                k--;
                r.unshift('');
              }
            }
            r.unshift($.trim($(row[j]).text()));
          }
          table_data.head.unshift(r);
        }
        for (i = c.rowsCopy.length; i; i) {
          i--;
          row = c.rowsCopy[i][0].cells;
          r = [];
          for (j = row.length; j; j) {
            j--;
            r.unshift($.trim($(row[j]).text()));
          }
          table_data.body.unshift(r);
        }
        $('#table_json'   ).val(JSON.stringify(table_data));
        $('#table_summary').val($(table).attr('summary'));
        $('#table_filter' ).val(c.filter_value);
        $('#export_json_table').attr({target: '_blank', action: '/action/ExportJsonTable/' + format}).submit();
        return;
      },
      ajaxUpdate: function (table) {
        var c = table.config;
        c.ajax_timer = false;
        c.ajax_obj = $.ajax({type:'GET',url:c.latest_url,data:'',dataType:'text',success:function(dt) {
          var m = dt.match(/^<span.*?>(\d+)<\/span>\s*(.*)$/);
          if( m ) {
            c.ajax_obj = false;
            c.entries = m[1];
            var old_rows = c.totalRowsRaw;
            c.totalRowsRaw = c.entries;
            c.totalRows    = c.entries;
            c.totalPages   = Math.ceil(c.totalRows / c.size);
            if( old_rows ) {
              $.tablesorter.clearTableBody(table);
            }
            if( c.entries ) {
              $(table).find('thead').last().after( m[2] );
              var tableBody = $(table.tBodies[0]);
              $.tablesorterPager.fixPosition(table, tableBody);
              $(table).trigger('applyWidgets');
            }
            $.tablesorterPager.updatePageDisplay(c, table);
          }
        }});
      },
      renderTable: function (table, rows) {
        var c = table.config, l = rows.length, s, e, i, l2, j, tableBody, o;
        if( c.refresh_url ) {
          // This is the really nasty bit of code which re-requests the TABLE!!
          var json_string = JSON.stringify({
            page:        c.page,
            size:        c.size,
            sort_list:   c.sortList,
            col_filters: $.grep($.map(c.col_filters,function(v,i){return [[i,v.val]];}),function(el) { return el[1] !== ''; })
          }).replace(/\\/g,'\\\\').replace(/'/g,'\\\'').replace(/"/g,'\\"');
          var URL = c.refresh_url.match(/[&?]pars=/) ? c.refresh_url+'+'+json_string : ( c.refresh_url+(c.refresh_url.match(/\?/)?'&':'?')+'pars='+encodeURIComponent(json_string));
          if( c.human_inter ) {
            if( URL !== c.latest_url ) {
              if( c.ajax_obj !== false ) {
                c.ajax_obj.abort();
              }
              if( c.ajax_timer !== false ) {
                window.clearTimeout(c.ajax_timer);
              }
              c.latest_url = URL;
              c.ajax_timer = window.setTimeout( function() { $.tablesorterPager.ajaxUpdate(table); }, c.ajax_key_delay );
            }
            return;
          } else {
            c.latest_url = URL;
          }
        }
        $.tablesorter.clearTableBody(table);
        if (l > 0) {
          if (c.page < 0) {
            c.page = 0;
          }
          if (c.page >= c.totalPages) {
            c.page = c.totalPages - 1;
          }
          s = (c.page * c.size);
          e = (s + c.size);
          if (e > l) {
            e = l;
          }

          tableBody = $(table.tBodies[0]);
          for (i = s; i < e; i++) {
            o = rows[i].clone(); // So IE 11 doesn't remove contents!
            l2 = o.length;
            for (j = 0; j < l2; j++) {
              tableBody[0].appendChild(o[j]);
            }
          }
        }
        $.tablesorterPager.fixPosition(table, tableBody);
        $(table).trigger('applyWidgets');
        $.tablesorterPager.updatePageDisplay(c, table);
      },

      changeFilter: function (table,  value) {
        var c = table.config;
        value = $.trim(value.toLowerCase());
        c.filter_value = value;

        $.tablesorterPager.filterRows(c);
        $.tablesorterPager.renderTable(table, c.rowsCopy);
      },
      changeColFilter: function (table) {
        var c = table.config, filter_values = $(table).find(table.config.cssColFilter), q = [], j = 0;
        filter_values.each(function () {
          var t = c.parsers[j].type,
              v = $.trim($(this).val().toLowerCase()),
              f = [],
              t_matches,
              k,
              t_match;
          if( t === 'numeric' && v.match(/[<=>]/) ) {
            t_matches = v.match(/([<=>]+\s*-?[\.\d]+)/g);
            if( t_matches ) {
              f = [];
              for (k = t_matches.length; k; k) {
                k--;
                t_match = t_matches[k].match(/([<=>]+)\s*(-?[\.\d]+)/);
                f.push( { cond: t_match[1], val: parseFloat(t_match[2]) } );
              }
            }
          } else if( t !== 'numeric' ) {
            if( v.charAt(0) === '/' ) {
              f.push( { cond: 'regexp', val: v.substr(1) } );
            } else if( v.charAt(0) === '^' ) {
              f.push( { cond: 'start', val: v.substr(1) } );
            } else if( v.charAt(v.length - 1) === '$' ) {
              f.push( { cond: 'end', val: v.substr(0, v.length - 1) } );
            }
          }
          q.push({ type:t, val: v, filters: f });
          j++;
        });
        c.col_filters = q;
        $.tablesorterPager.filterRows(c);
        $.tablesorterPager.renderTable(table, c.rowsCopy);
      },
      filterRows: function (c) {
        var values = c.col_filters, value = c.filter_value, val_filtering = value !== '', col_filtering = values.join('') !== '', i, x, row, flag, j, col_val, filter, k;
        if( c.refresh_url ) {
          c.rowsCopy = c.rowsCopyRaw;
          return;
        }
        if ( !val_filtering && !col_filtering) {
          c.rowsCopy = c.rowsCopyRaw;
        } else {
          c.rowsCopy = [];
          for (i = c.rowsCopyRaw.length; i; i) {
            i--;
            x = c.rowsCopyRaw[i];
            row = x[0].cells;
            flag = 1;
            if (val_filtering) {
              flag = 0;  // We need to look for a match!
              for (j = row.length; j; j) {
                j--;
                if ($(row[j]).text().toLowerCase().indexOf(value) >= 0) {
                  flag = 1;
                  break;
                }
              }
            }
            /* jshint -W073 */
            if (col_filtering) { // We need any column with a filter value to match
              for (j = row.length; j; j) {
                j--;
                if (values[j].val !== '') {
                  col_val = parseFloat($(row[j]).text(), 10);
                  if (values[j].type === 'numeric' && values[j].filters.length) {
                    // Numeric sort and request is a range!
                    for (k = values[j].filters.length; k; k) {
                      k--;
                      filter = values[j].filters[k];
                      if(
                        filter.cond === '<'  && filter.val <= col_val  ||
                        filter.cond === '<=' && filter.val <  col_val  ||
                        filter.cond === '>'  && filter.val >= col_val  ||
                        filter.cond === '>=' && filter.val >  col_val  ||
                        filter.cond === '='  && filter.val !== col_val ||
                        filter.cond === '==' && filter.val !== col_val ) {
                        flag = 0;
                        break;
                      }
                    }
                    if( flag === 0 ) {
                      break;
                    }
                  } else {
                    if ( $(row[j]).text().toLowerCase().indexOf(values[j].val) < 0) {
                      flag = 0;
                      break;
                    }
                  }
                }
              }
            }
            /* jshint +W073 */
            if (flag) {
              c.rowsCopy.unshift(x);
            }
          }
        }
        c.totalRows    = c.rowsCopy.length;
        c.totalPages   = Math.ceil(c.totalRows / c.size);
        if (c.page >= (c.totalPages - 1)) {
          c.page = (c.totalPages - 1);
        }
      },
      appender: function (table, rows) {
        var c = table.config;

        c.rowsCopyRaw  = rows;
        c.totalRowsRaw = rows.length;

        $.tablesorterPager.filterRows(c);
        if( c.entries ) {
          c.totalRowsRaw = c.entries;
          c.totalRows    = c.entries;
        }
        c.totalPages   = Math.ceil(c.totalRows / c.size);

        $.tablesorterPager.renderTable(table, c.rowsCopy);
      },
      defaults: {
        size: 10000000,
        filter_value: '',
        col_filters: [],
        refresh_url: '',
        export_url:  '',
        entries: 0,
        latest_url: '',
        human_inter: 0,
        offset: 0,
        page: 0,
        showCount: 1,
        totalRows: 0,
        totalPages: 0,
        container: null,
        cssFilter: '.filter',
        cssColFilter: '.colfilter',
        cssNext: '.next',
        cssPrev: '.prev',
        cssFirst: '.first',
        cssLast: '.last',
        cssDump: '.jsondump',
        cssPageDisplay: '.pagedisplay',
        cssPageSize: '.pagesize',
        seperator: '/',
        positionFixed: false,
        //appender: this.appender,
        ajax_key_delay: 200,
        ajax_timer: false,
        ajax_obj: false,
        n_end: 1,
        n_pad: 2
      },

      construct: function (settings) {
        return this.each(function () {
          $.tablesorterPager.defaults.appender = $.tablesorterPager.appender;
          var config = $.extend(this.config, $.tablesorterPager.defaults, settings), table = this, pager = config.container, new_size;
          $(this).trigger('appendCache');
          new_size = $('.pagesize', pager).length ? parseInt($('.pagesize', pager).val(), 10) : 0;
          if (new_size !== config.size && new_size !== 0) {
            $.tablesorterPager.setPageSize(table,  new_size);
          }
          config.human_inter = 1;
          /* We have now set up the page appropriately ... now if we are doing on page updates this is
             where we need to start hacking! */
          $(config.cssDump, pager).click(function () {
            if( config.export_url ) {
              var json_string = JSON.stringify({
                page:        config.page,
                size:        config.size,
                sort_list:   config.sortList,
                col_filters: $.grep($.map(config.col_filters,function(v,i){return [[i,v.val]];}),function(el) { return el[1] !== ''; })
              });
              var URL = config.export_url+(config.export_url.match(/\?/)?'&':'?')+'config='+encodeURIComponent(json_string);
              document.location.href = URL;
              return false;
            } else {
              $.tablesorterPager.get_json(table, $(this).html());
              return false;
            }
          });
          $(config.cssFilter, pager).keyup(function () {
            $.tablesorterPager.changeFilter(table, $(this).val());
            return false;
          });
          $(config.cssColFilter, table).keyup(function () {
            $.tablesorterPager.changeColFilter(table);
            return false;
          });
          $(config.cssColFilter, table).change(function () {
            $.tablesorterPager.changeColFilter(table);
            return false;
          });
          $(config.cssPageDisplay + ' span', pager).click(function () {
            $.tablesorterPager.moveToLinkPage(table, $(this).html());
            return false;
          });
          $(config.cssPageSize, pager).change(function () {
            $.tablesorterPager.setPageSize(table, parseInt($(this).val(), 10));
            return false;
          });
        });
      }
    }
  });
  // extend plugin scope
  $.fn.extend({
    tablesorterPager: $.tablesorterPager.construct
  });
}(jQuery));
