(function ($) {
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
        var c = table.config, table_data = { head: [],  body: [] }, th = table.tHead, i, row, r, j;
        for (i = table.tHead.rows.length;  i; i) {
          i--;
          row = table.tHead.rows[i].cells;
          r = [];
          for (j = row.length; j; j) {
            j--;
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
        $('#table_json').val(JSON.stringify(table_data));
        $('#table_summary').val($(table).attr('summary'));
        $('#table_filter').val(c.filter_value);
        $('#export_json_table').attr({target: '_blank', action: '/action/ExportJsonTable/' + format}).submit();
        return;
      },

      renderTable: function (table, rows) {

        var c = table.config, l = rows.length, s, e, i, l2, j, tableBody, o;
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

          // clear the table body

          for (i = s; i < e; i++) {
            o = rows[i];
            l2 = o.length;
            for (j = 0; j < l2; j++) {
              tableBody[0].appendChild(o[j]);
            }
          }
        }
        $.tablesorterPager.fixPosition(table, tableBody);

        $(table).trigger("applyWidgets");

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
          var t = c.parsers[j].type, v = $.trim($(this).val().toLowerCase()),f=[],t_matches,k,t_match;
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
        if (!val_filtering && !col_filtering) {
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
        c.totalPages   = Math.ceil(c.totalRows / c.size);

        $.tablesorterPager.renderTable(table, c.rowsCopy);
      },
      defaults: {
        size: 10000000,
        filter_value: '',
        col_filters: [],
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
        seperator: "/",
        positionFixed: false,
        appender: this.appender,
        n_end: 1,
        n_pad: 2
      },

      construct: function (settings) {
        return this.each(function () {
          $.tablesorterPager.defaults.appender = $.tablesorterPager.appender;
          var config = $.extend(this.config, $.tablesorterPager.defaults,  settings), table = this, pager = config.container, new_size;
          $(this).trigger("appendCache");
          new_size = $(".pagesize", pager).length ? parseInt($(".pagesize", pager).val(), 10) : 0;
          if (new_size !== config.size && new_size !== 0) {
            $.tablesorterPager.setPageSize(table,  new_size);
          }
          $(config.cssDump, pager).click(function () {
            $.tablesorterPager.get_json(table, $(this).html());
            return false;
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
