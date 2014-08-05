(function($){
  'use strict';
  /*jslint regexp: true */
  /*globals console: true */
  /*----------------------------------------------------------------------
    Some core support functions - rendering lists and tables from
    data structures etc...

    author: js5 (James Smith)
    svn-id: $Id$
  ------------------------------------------------------------------------

  ----------------------------------------------------------------------*/

  function val_check(type, val, match_value) {
    if ((type === 'exact'     && val !== match_value) ||
        (type === 'true'      && !val) ||
        (type === 'contains'  && val.toString.indexOf(match_value) === -1) ||
        (type === 'lt'        && val >= match_value) ||
        (type === 'gt'        && val <= match_value) ||
        (type === 'le'        && val >  match_value) ||
        (type === 'ge'        && val <  match_value)) {
      return 1;
    }
    return 0;
  }

  Pagesmith.escapeHTML = function(string) {
    return (string === null || typeof (string) === 'undefined') ? string : $('<div/>').text(string).html();
  };

  Pagesmith.clean = function (v, d) {
    return (v === null || typeof (v) === 'undefined') ? d : v;
  };

  Pagesmith.cleanfloat = function (v, d) {
    return (v === null || typeof (v) === 'undefined') ? d : parseFloat(v);
  };

  Pagesmith.expand_format = function (format, val) {
    var f, k, format_ref, match, perc;
    if (typeof (val) === 'undefined' || val === null) {
      return val;
    }
    if (typeof (format) === 'object') {
      for (k = 0; k < format.length; k++) {
        format_ref = format[k];
        if (!val_check(format_ref[1],  val, format_ref[2])) {
          f = format_ref[0];
          break;
        }
      }
    } else {
      f = format;
    }
    if (typeof (f) === 'undefined' || f === '') {
      f = 'h';
    }

    match = f.match(/^([efgp])(\d*)$/);
    if (match) {
      switch (match[1]) {
      case 'e':
        return parseFloat(val).toExponential(match[2] || 6);
      case 'f':
        return parseFloat(val).toFixed(match[2] || 0);
      case 'g':
        return parseFloat(val).toPrecision(match[2] || 3);
      default: // case 'p'
        perc = 100 * parseFloat(val);
        return perc.toFixed(match[2] || 0) + '%';
      }
    }
    switch (f) {
    case 'd':
      return parseFloat(val).toFixed(0);
    case 'r':
      return val;
    case 's':
      return val.replace(/\W+/g,'_');
    case 'u':
    case 'ur':
      // url encode
      return encodeURI(val);
    default: // encode entities
      return Pagesmith.escapeHTML(val);
    }
  };

  Pagesmith.expand_link = function (link_template, val, row, text) {
    var M, url;
    if (text === '') {
      return '';
    }
    url = Pagesmith.expand_template(link_template, val, row);
    if (url === '') {
      return text;
    }
    M = url.split(/\s+/);
    if (M.length > 1) {
      url = M.shift();
      return '<a class="' + M.join(' ') + '" href="' + url + '">' + text + '</a>';
    }
    return '<a href="' + url + '">' + text + '</a>';
  };

  Pagesmith.expand_template = function (template, val, row) {
    var result = '', t = '', k, template_ref, match, type, part, match2, perc;
    if (typeof (val) === 'undefined' || val === null) {
      return val;
    }
    if (typeof (template) === 'object') {
      for (k = 0; k < template.length; k++) {
        template_ref = template[k];
        if (!val_check(template_ref[1],  row[template_ref[2]], template_ref[3])) {
          t = template_ref[0];
          break;
        }
      }
    } else {
      t = template;
    }
    while (t.length > 0) {
      match = t.match(/^(.*?)\[\[([efgp]:\d+:[\-\w]+|[ruhdefsgp]:[\-\w]+|[\-\w]+)\]\](.*)$/);
      if (match) {
        result += match[1];
        type = match[2].substr(0, 2);
        part = match[2].substr(2);
        switch (type) {
        case 'r:':
          result += Pagesmith.clean(row[part], '');
          break;
        case 'u:':
          result += encodeURI(Pagesmith.clean(row[part], ''));
          break;
        case 'h:':
          result += Pagesmith.escapeHTML(Pagesmith.clean(row[part], ''));
          break;
        case 's:':
          result += Pagesmith.clean(row[part],'').replace(/\W+/g,'_');
          break;
        case 'e:':
          match2 = part.match(/(\d+):(\w+)/);
          result += Pagesmith.cleanfloat(row[match2 ? match2[2] : part], 0).toExponential(match2 ? match2[1] : 6);
          break;
        case 'g:':
          match2 = part.match(/(\d+):(\w+)/);
          result += Pagesmith.cleanfloat(row[match2 ? match2[2] : part], 0).toPrecision(match2 ? match2[1] : 3);
          break;
        case 'f:':
          match2 = part.match(/(\d+):(\w+)/);
          result += Pagesmith.cleanfloat(row[match2 ? match2[2] : part], 0).toFixed(match2 ? match2[1] : 0);
          break;
        case 'p:':
          match2 = part.match(/(\d+):(\w+)/);
          perc = 100 * Pagesmith.cleanfloat(row[match2 ? match2[2] : part], 0);
          result += perc.toFixed(match2 ? match2[1] : 1) + '%';
          break;
        case 'd:':
          result += Pagesmith.cleanfloat(row[part], 0).toFixed(0);
          break;
        default:
          result += Pagesmith.escapeHTML(Pagesmith.clean(row[match[2]]));
          break;
        }
        t = match[3];
      } else {
        result += t;
        break;
      }
    }
    return result;
  };

  Pagesmith.Select = function (options, data) {
    this.options = options || {};
    this.data    = data    || [];
  };

  Pagesmith.Select.prototype = {
    expand_template: Pagesmith.expand_template,
    render: function () {
      var rows = [], i;
      for (i = this.data.length; i; i--) {
        rows.unshift('<option value="' +
          this.expand_template(this.options.value_template, '-', this.data[i - 1]) + '">' +
          this.expand_template(this.options.label_template, '-', this.data[i - 1]) + '</option>');
      }
      if (this.options.first_line) {
        rows.unshift('<option value="">' + this.options.first_line + '</option>');
      }
      return '<select id="' + this.options.id + '" name="' + this.options.name + '">' + rows.join('') + '</select>';
    }
  };

  Pagesmith.Tabs = function (options) {
    this.tabs    = [];
    this.options = options || {};
    this.classes = [];
  };

  Pagesmith.Tabs.prototype = {
    add_tab: function (name, title, content, flag) {
      if (typeof (flag) === 'undefined') {
        flag = { 'pos': 'left' };
      }
      this.tabs.push({ name: name, title: title, content: content, flag: flag });
      return this;
    },
    unshift_tab: function (name, title, content, flag) {
      if (typeof (flag) === 'undefined') {
        flag = 'left';
      }
      this.tabs.unshift({ name: name, title: title, content: content, flag: flag });
      return this;
    },
    attach_functions: function () {
      var j, t, x;
      for (j = this.tabs.length; j; j--) {
        t = this.tabs[j - 1];
        if (typeof (t.content) === 'function') {
          x = t.content;
          $('a[href=#' + t.name + ']').bind('click', x);
        }
      }
      return this;
    },
    classes_string: function () {
      var a = this.classes;
      a.unshift(this.options.fake ? 'fake-tabs' : 'tabs');
      return a.join(' ');
    },
    add_classes: function () {
      var i, l = arguments.length;
      for (i = l; i; i) {
        this.classes.push(arguments[l-i]);
        i--;
      }
      return this;
    },
    render: function () {
      var j, nav = [], navr = [], contents = [], t, extra, html;
      for (j = this.tabs.length; j; j) {
        j--;
        t = this.tabs[j];
        /* Navigation links... */
        if (t.flag.pos === 'right') {
          navr.unshift('<li class="rtab"><a href="#' + t.name + '">' + t.title + '</a></li>');
        } else {
          nav.unshift('<li><a href="#' + t.name + '">' + t.title + '</a></li>');
        }
        /* Now for the content... */
        extra = t.flag.scrollable ? 'scrollable' : (t.flag.classname || '');
        if (j) {
          extra = extra ? extra + ' tabc_hid' : 'tabc_hid';
        }
        if (extra) {
          extra = ' class="' + extra + '"';
        }
        contents.unshift('<div id="' + t.name + '"' + extra + '>' + t.content + '</div>');
      }
      html = '<ul class="' + this.classes_string() + '">' + nav.join('') + '</ul>';
      if (navr.length) {
        html += '<ul class="' + this.classes_string() + ' navr">' + navr.join('') + '</ul>';
      }
      if (this.options.template) {
        return this.options.template.replace(/##nav##/, html).replace(/##body##/, contents.join(''));
      }
      html += contents.join('');
      return html;
    }
  };

  Pagesmith.Table = function (options, structure, data) {
    this.data      = data       || [];
    this.options   = options    || {};
    this.structure = structure  || [];
  };

  Pagesmith.Table.prototype = {
    expand_template: Pagesmith.expand_template,
    expand_format:   Pagesmith.expand_format,
    expand_link:     Pagesmith.expand_link,
    render: function () {
      var j, t, h = [], rs, tr_class, i, row, tr_x, k, row_class_ref, r, c, result, tr_tag, new_class;
      for (j = this.structure.length; j; j--) {
        t = this.structure[j - 1];
        h.unshift('<th>' + t.label + '</th>');
      }
      if (this.options.index) {
        h.unshift('<th>#</th>');
      }
      rs = [];
      tr_class = this.options.fake ? 'odd ' : 'even ';
      for (i = this.data.length; i; i--) {
        row = this.data[i - 1];
        tr_x = tr_class;
        if (this.options.row_class) {
          new_class = '';
          if (typeof (this.options.row_class) === 'object') {
            for (k = 0; k <= this.options.row_class.length; k++) {
              row_class_ref = this.options.row_class[k];
              if (!val_check(row_class_ref[1], row[row_class_ref[2]], row_class_ref[3])) {
                new_class = row_class_ref[0];
                break;
              }
            }
          } else {
            new_class = this.options.row_class;
          }
          if (new_class !== '') {
            tr_x += this.expand_template(new_class,'',row);
          }
        }
        if (tr_x) {
          tr_tag = '<tr class="' + tr_x + '">';
        } else {
          tr_tag = '<tr>';
        }
        r = [];
        for (j = this.structure.length; j; j--) {
          t = this.structure[j - 1];
          c = row[t.key];
          result = t.template ? this.expand_template(t.template, c, row) :
                (t.format ? this.expand_format(t.format, c) : c);
          if (result === null || typeof (result) === 'undefined') {
            result = t.def;
          } else if (t.link && c !== '') {
            result = this.expand_link(t.link, c, row, result);
          }
          r.unshift('<td class="' + t.align + '">' + result + '</td>');
        }
        if (this.options.index) {
          r.unshift('<td class="r">' + i + '</td>');
        }
        rs.unshift(tr_tag + r.join('') + '</tr>');
        if (tr_class === 'odd ') {
          tr_class = 'even ';
        } else if (tr_class === 'even ') {
          tr_class = 'odd ';
        }
      }
      if( this.options.noheading ) {
        return '<table class="' + this.options.className + '"><tbody>' + rs.join('') + '</tbody></table>';
      }
      return '<table class="' + this.options.className + '"><thead><tr>' + h.join('') + '</tr></thead><tbody>' + rs.join('') + '</tbody></table>';
    }
  };


  /* helper functions... rewrite status div */
  Pagesmith.Timer = {
    t0: 0,
    set_status: function (string) {
    /*jsl:ignore*/
      if (typeof (console) !== 'undefined') {
        var d = new Date(), t = d.getTime(), lt = (t - this.t0) / 1e3;
        if (console) {
          console.log(lt + ' : ' + string);
        }
      }
    /*jsl:end*/
      $('#status').html(string);
    },
    init: function () {
      var d = new Date();
      this.t0 = d.getTime();
    }
  };

  $(function(){
    Pagesmith.On.load( 'h2.make-wide, h3.make-wide', function(){
      $(this).append('<span class="toggle-width" title="Full width">&#x21d4;</span>');
    });
  });
  $('body')
    .on('click','#main  .toggle-width',function() { $('#main').attr('id','mainx'); $('#rhs').attr('id','rhsx'); $(this).html('&lArr;').attr('title','Show navigation'); $(window).trigger('resize');} )
    .on('click','#mainx .toggle-width',function() { $('#mainx').attr('id','main'); $('#rhsx').attr('id','rhs'); $(this).html('&#x21d4;').attr('title','Full width'); $(window).trigger('resize');} );

  /* On resize function to give "relative heights" to containers! */
  Pagesmith.getPageSize = function() {
    var de = document.documentElement;
    return {w: window.innerWidth  || (de&&de.clientWidth)  || document.body.clientWidth,
            h: window.innerHeight || (de&&de.clientHeight) || document.body.clientHeight };
  };

  $('body').on('click','.confirm-click',function() {
    return window.confirm( $.metadata && $(this).metadata() && $(this).metadata().msg ? $(this).metadata().msg : 'Are you sure' );
  });

  $(window).on('resize', function() {
    $('.vert-sizing').each(function(){
      var config = $.extend({},
        { padding: 200, minheight: 400 },
        $.metadata && $(this).metadata() ? $(this).metadata() : {});
      $(this).css('height',Math.max( (Pagesmith.getPageSize()).h-config.padding,config.minheight )+'px' );
    });
  });
  $(window).trigger('resize');
}(jQuery));
