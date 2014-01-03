var Chartsmith;

(function($){
  'use strict';
  /* globals Raphael: true */
  /**
    Author: James Smith (js5)

    Generic 2d charting package, which can display data on linear, log and discrete axis
  */

  // Extend the String object to add a "repeater"... e.g. '0'.rep(100);

  /* jshint freeze: false */
  String.prototype.rep = function (n) {
    var x = this, y;
    n = parseInt(n, 10);
    if (n <= 0) {
      return '';
    }
    y = '';
    while (n) {
      if (n % 1) {
        y += x;
        n--;
      }
      n /= 2;
      x += x;
    }
    return y;
  };
  /* jshint freeze: true */

  Chartsmith = {
    Collector: {},
    Bump: function (options) {
      var x;
      this.start       = options.start;
      this.end         = options.end;
      if (this.end < this.start) {
        x          = this.end;
        this.end   = this.start;
        this.start = x;
      }
      this.width       = options.width;
      this.s_0         = '0'.rep(options.width);
      this.s_1         = '1'.rep(options.width);
      this.bump_array  = [];
      this.height      = 0;
      this.len         = options.end - options.start + 1;
      this.factor      = this.width / this.len;
    }
  };

  Chartsmith.Bump.prototype = {
    reset: function () {
      this.height     = 0;
      this.bump_array = [];
    },
    scale: function (bp1, bp2, min_width) {
      var l = (bp1    - this.start) * this.factor, r = (bp2 + 1 - this.start) * this.factor;
      if (l > this.width) {
        return {first: -1, last: -1};
      }
      if (l < 0) {
        l = 0;
      }
      if (r < 0) {
        return {first: -1, last: -1};
      }
      if (r - l < min_width) {
        r = l + min_width;
      }
      if (r > this.width) {
        r = this.width;
      }
      return { first: Math.floor(l), last: Math.ceil(r) };
    },
    add_feature: function (bp1, bp2, min_width) {
      var t = this.scale(bp1, bp2, min_width),l,z;
      if (t.first === -1) {
        return -1;
      }
      for (l = 0; l < this.height; l++) {
        z = this.bump_array[l].substr(t.first, t.last);
        if (!parseInt(z, 10)) {
          this.bump_array[l] = this.bump_array[l].substr(0, t.first) + this.s_1.substr(0, t.last - t.first) + this.bump_array[l].substr(t.last, this.width - t.last);
          return l;
        }
      }
      this.bump_array.push(this.s_0.substr(0, t.first) + this.s_1.substr(0, t.last - t.first) + this.s_0.substr(t.last, this.width - t.last));
      this.height++;
      return this.height - 1;
    }
  };

  Raphael.fn.cs_merge = function (keys, pars) {
    var key, key_n, prop;
    for (key_n in keys) {
      if (typeof (keys[key_n]) !== 'function') {
        key  = keys[key_n];
        if (typeof (pars[key]) === 'object') {
          for (prop in this.cs[key]) {
            if (typeof (this.cs[key][prop]) !== 'function' && typeof (pars[key][prop]) !== 'undefined') {
              this.cs[key][prop] = pars[key][prop];
            }
          }
        } else if (typeof (pars[key]) !== 'undefined') {
          this.cs[key] = pars[key];
        }
      }
    }
  };


  /**
  Constructor: initialize parameters (copy from passed pars hash)
  */
  Raphael.fn.cs_init = function (pars) {
    // Store the object in the collector so that we can get it back later...
    Chartsmith.Collector[pars.object] = this;
    this.cs = {
      height:     null,
      width:      null,
      popup_text: null,
      popup_box:  null,
      margins:    { left: 20, right: 20, top: 20, bottom: 20 }, // Configuration setting for margins
      xaxis:      { label_style: '', minvalue: null, maxvalue: null, dir: '+', label: '', line: null,
                    scaling: 'linear', major: 1, minor: 1, axis_pos: 'below', labelsize: 14, size: 10,
                    ticksize: 4, values: [], label_scale: 0, label_dp: 0, label_suffix: '', hide: 0,
                    precision: 3, colour: '#000'
                  }, // Configurat
      yaxis:      { label_style: '', minvalue: null, maxvalue: null, dir: '-', label: '', line: null,
                    scaling: 'linear', major: 1, minor: 1, axis_pos: 'left',  labelsize: 14, size: 10,
                    ticksize: 4, values: [], label_scale: 0, label_dp: 0, label_suffix: '', hide: 0,
                    label_len: 6, precision: 3, colour: '#000'
                  },
      background: '#eee',
      title:      { text: undefined, position: 'above', size: 20, fill: '#000', offset: 5 },
      edge:       '',
      notIE:      document.all ? false : true
    };
    this.cs_merge([ 'xaxis', 'yaxis', 'background', 'title', 'edge', 'margins' ], pars);
  // Default margin = 20px
    this.cs.width  = $('#' + pars.object).width();
    this.cs.height = $('#' + pars.object).height();
    this.setSize( this.cs.width, this.cs.height );
  //  Left margin needs to be expanded IF
  //   * the y-axis has a label
    if (this.cs.yaxis.label) {
      this.cs.margins.left += this.cs.yaxis.labelsize;
    }
    //   * the y-axis numbering is on the left hand side!
    if (!this.cs.yaxis.hide) {
      if (this.cs.yaxis.axis_pos === 'left' || this.cs.yaxis.scaling  === 'discrete' ||
        (this.cs.yaxis.axis_pos === 'on' && (this.cs.yaxis.scaling === 'log' ? 1 : 0) < this.cs.yaxis.minvalue)) {
        this.cs.margins.left += this.cs.yaxis.size * this.cs.yaxis.label_len * 0.6 + 10;
      }
    }
  //  Bottom margin needs to be expanded IF
  //   * the x-axis has a label
    if (this.cs.xaxis.label) {
      this.cs.margins.bottom += this.cs.xaxis.labelsize;
      this.cs.title.offset   += this.cs.xaxis.labelsize;
    }
    if (!this.cs.xaxis.hide) {
      //   * the x-axis numbering is on the bottom edge!
      if (this.cs.xaxis.axis_pos === 'above' || this.cs.xaxis.axis_pos === 'below' || this.cs.xaxis.scaling  === 'discrete' ||
           (this.cs.xaxis.axis_pos === 'on' && (this.cs.xaxis.scaling === 'log' ? 1 : 0) < this.cs.xaxis.minvalue)) {
        if (this.cs.xaxis.axis_pos === 'above') {
          this.cs.margins.top    += this.cs.xaxis.size + 10;
        } else {
          this.cs.margins.bottom += this.cs.xaxis.size + 10;
          this.cs.title.offset   += this.cs.xaxis.size + 10;
        }
      }
    }
  //   * the graph has a title and it's position is set to bottom!
    if (this.cs.title.text && this.cs.title.position === 'below' && this.cs.title.text) {
      this.cs.margins.bottom += this.cs.title.size;
    }

  //  Top margin needs to be expanded IF
  //  * the graph has a title and it's position is set to top!
    if (this.cs.title.text && this.cs.title.position !== 'below' && this.cs.title.text) {
      this.cs.margins.top += this.cs.title.size;
    }

  //  Right margin needs to be expanded IF
  //   * the graph has a key (and position is right)

  /* Explicitly set the margins if set in the parameters */
  //  this.cs_merge(['margins'], pars);
    if (!this.cs.edge) {
      this.cs.edge = this.cs.background;
    }
    this.cs_draw_canvas();
  };

  Raphael.fn.cs_tweak_axis = function (axis) {
    var pts, i;
    axis.length   = axis.end - axis.start;
    if (axis.scaling === 'discrete') {
      pts = axis.values;
      axis.mult = axis.length / pts.length;
      axis.invert = {};
      for (i = pts.length; i; i--) {
        axis.invert[pts[i - 1]] = i - 1;
      }
      return;
    }
    if (axis.scaling === 'log') {
      axis.mult = axis.length / Math.log(axis.maxvalue / axis.minvalue);
      return;
    }
    axis.cp   = (axis.start + axis.end) / 2;
    axis.mult = axis.length / (axis.maxvalue - axis.minvalue);
    return;
  };
  /**
  Initializer - actually initialize object
   * Grab the object div;
   * Create the raphael object
   * Configure and render the background
   * Configure and render the axes
  */
  Raphael.fn.cs_max_length = function ( txts, fs ) {
    var self = this,max_len=0;
    fs = typeof( fs ) !== 'undefined' ? fs : 0;
    $.each(txts,function(i,txt){
      var t = self.text(0,0, txt.toString()),w;
      if( fs ) {
        t.attr('font-size',fs);
      }
      w = t.getBBox().width;
      t.remove();
      if( w > max_len ) {
        max_len = w;
      }
    });
    return max_len;
  };

  /* jshint -W074 */
  Raphael.fn.cs_draw_canvas = function () {
    var x_ticks, y_ticks, i, tck, t, B, bw, tb1, BB1, BB2, tb2, BB3, tb3, mb, A, ma, AA, mult, ticksize, text_pos;
  /*
  Configure the axes
  */
    this.cs.xaxis.start  = this.cs.margins.left;
    this.cs.xaxis.end    = this.cs.width  - this.cs.margins.right;
    this.cs.yaxis.start  = this.cs.margins.top;
    this.cs.yaxis.end    = this.cs.height - this.cs.margins.bottom;
    this.cs_tweak_axis(this.cs.xaxis);
    this.cs_tweak_axis(this.cs.yaxis);
    if (this.cs.xaxis.axis_pos === 'above') {
      this.cs.xaxis.pos = this.cs.yaxis.start;
    } else {
      if (this.cs.xaxis.axis_pos === 'below' || this.cs.yaxis.scaling === 'discrete') {
        this.cs.xaxis.pos = this.cs.yaxis.end;
      } else {
        this.cs.xaxis.pos = this.cs_scale_y(this.cs.yaxis.scaling === 'log' ? 1 : 0);
        if (this.cs.xaxis.pos === '+' || this.cs.xaxis.pos === '-') {
          this.cs.xaxis.pos = this.cs.yaxis.end;
        }
      }
    }
    if (this.cs.yaxis.axis_pos === 'left' || this.cs.xaxis.scaling === 'discrete') {
      this.cs.yaxis.pos = this.cs.xaxis.start;
    } else {
      this.cs.yaxis.pos  = this.cs_scale_x(this.cs.xaxis.scaling === 'log' ? 1 : 0);
      if (this.cs.yaxis.pos === '+' || this.cs.yaxis.pos === '-') {
        this.cs.yaxis.pos  = this.cs.xaxis.start;
      }
    }
  //    alert(this.cs.xaxis.pos + ' = ' + this.cs.yaxis.pos);
  //    alert(this.cs.xaxis.scaling+ ' - ' + this.cs.yaxis.scaling);

  /* Draw the background! */
    this.rect(this.cs.xaxis.start, this.cs.yaxis.start, this.cs.xaxis.length, this.cs.yaxis.length).attr({ 'fill': this.cs.background, 'stroke': this.cs.edge });

  /** Draw title **/
    if (this.cs.title.text) {
      this.cs_add_text({
        raw: 1,
        x: (this.cs.xaxis.start + this.cs.xaxis.end) / 2,
        y: this.cs.title.position === 'below' ? (this.cs.yaxis.end + this.cs.title.offset + this.cs.title.size / 2) : (this.cs.title.size / 2 + 5),
        t: this.cs.title.text,
        opts: {fill: this.cs.title.fill, 'font-size': this.cs.title.size + 'px', 'font-weight': 'bold'}
      });
    }
  /** Draw x-axis **/
    // Get the this.cs.xaxis.pos of the x-axis
    x_ticks = this.cs_get_ticks(this.cs.xaxis);
    y_ticks = this.cs_get_ticks(this.cs.yaxis);
    mult     = this.cs.xaxis.axis_pos === 'above' ? -1 : 1;
    ticksize = mult * this.cs.xaxis.ticksize;
    text_pos = this.cs.xaxis.pos + ticksize + mult * (this.cs.xaxis.size / 2 + 2);
    if (!this.cs.xaxis.hide) {
      for (i = x_ticks.length; i; i--) {
        tck = x_ticks[i - 1];
        if (tck.line) {
          this.cs_add_line({
            raw: 1,
            stroke: tck.line,
            pts: [ tck.pos, this.cs.yaxis.start, tck.pos, this.cs.yaxis.end ]
          });
        }
        this.cs_add_line({
          raw: 1,
          stroke: this.cs.xaxis.colour,
          pts: [ tck.pos, this.cs.xaxis.pos, tck.pos, this.cs.xaxis.pos + ticksize ]
        });
        if (typeof (tck.label) !== 'undefined') {
          /* this.cs_add_text({
            raw:1 ,x: tck.pos, y: this.cs.xaxis.pos+this.cs.xaxis.ticksize+this.cs.xaxis.size/2+8,
            t: tck.label, opts: { fill: '#000', 'font-size': this.cs.xaxis.size+'pt' }, rot: -60, align: 'right'  });
          */
          B = tck.label.toString();
          mb = B.match(/^10\^(-?\d+)(\w*)$/);
          if (mb) {
            bw = 0;
            BB1 = 0;
            if (mb[3]) {
              tb1 = this.cs_add_text({ raw: 1, x: tck.pos, y: text_pos, t: mb[2], opts: { fill: this.cs.xaxis.colour, 'font-size': this.cs.xaxis.size } });
              BB1 = tb1.getBBox().width / 2;
            }
            tb2 = this.cs_add_text({ raw: 1, x: tck.pos, y: text_pos - 3, t: mb[1], opts: { fill: this.cs.xaxis.colour, 'font-size': this.cs.xaxis.size * 0.6 } });
            BB2 = tb2.getBBox().width / 2;
            tb3 = this.cs_add_text({ raw: 1, x: tck.pos, y: text_pos, t: '10', opts: { fill: this.cs.xaxis.colour, 'font-size': this.cs.xaxis.size } });
            BB3 = tb3.getBBox().width / 2;
            if (tb1) {
              tb1.translate(BB2 + BB3, 0);
            }
            tb2.translate(BB3 - BB1, 0);
            tb3.translate(-BB1 - BB2, 0);
          } else {
            this.cs_add_text({ raw: 1, x: tck.pos, y: text_pos, t: tck.label, opts: { fill: this.cs.xaxis.colour, 'font-size': this.cs.xaxis.size } });
          }
        }
      }
      this.cs_add_line({
        raw: 1,
        stroke: this.cs.xaxis.colour,
        pts: [ this.cs.xaxis.start, this.cs.xaxis.pos, this.cs.xaxis.end, this.cs.xaxis.pos ]
      });
    }
    if (!this.cs.yaxis.hide) {
      for (i = y_ticks.length; i; i--) {
        tck = y_ticks[i - 1];
        if (tck.line) {
          this.cs_add_line({
            raw: 1,
            stroke: tck.line,
            pts: [ this.cs.xaxis.start, tck.pos, this.cs.xaxis.end, tck.pos ]
          });
        }
        this.cs_add_line({
          raw: 1,
          stroke: this.cs.yaxis.colour,
          pts: [ this.cs.yaxis.pos, tck.pos, this.cs.yaxis.pos - this.cs.yaxis.ticksize, tck.pos ]
        });
        if (typeof (tck.label) !== 'undefined') {
          A = tck.label.toString();
          ma = A.match(/^10\^(-?\d+)(\w*)$/);
          AA = this.cs.yaxis.pos - this.cs.yaxis.ticksize - 5;
          if (ma) {
            if (ma[2]) {
              t = this.cs_add_text({ align: 'right', raw: 1, x: AA, y: tck.pos, t: ma[2], opts: { fill: this.cs.yaxis.colour, 'font-size': this.cs.yaxis.size } });
              AA -= t.getBBox().width;
            }
            t = this.cs_add_text({ align: 'right', raw: 1, x: AA, y: tck.pos - 3, t: ma[1], opts: { fill: this.cs.yaxis.colour, 'font-size': this.cs.yaxis.size * 0.6 } });
            AA -= t.getBBox().width;
            t = this.cs_add_text({ align: 'right', raw: 1, x: AA, y: tck.pos, t: '10', opts: { fill: this.cs.yaxis.colour, 'font-size': this.cs.yaxis.size } });
          } else {
            t = this.cs_add_text({ align: 'right', raw: 1, x: AA, y: tck.pos, t: tck.label, opts: { fill: this.cs.yaxis.colour, 'font-size': this.cs.yaxis.size } });
          }
        }
      }
      this.cs_add_line({
        raw: 1,
        stroke: this.cs.yaxis.colour,
        pts: [ this.cs.yaxis.pos, this.cs.yaxis.start, this.cs.yaxis.pos, this.cs.yaxis.end ]
      });
    }
    if (this.cs.yaxis.label) {
      t = this.cs_add_text({
        raw: 1,
        x: this.cs.yaxis.labelsize / 2 + 5,
        y: this.cs.yaxis.start + this.cs.yaxis.length / 2,
        t: this.cs.yaxis.label,
        opts: {fill: this.cs.yaxis.colour, font: this.cs.yaxis.labelsize + 'px Arial', 'font-weight': 'bold'}
      });
      t.rotate(-90);
    }

    if (this.cs.xaxis.label) {
      t = this.cs_add_text({
        raw: 1,
        y: this.cs.yaxis.end + this.cs.xaxis.labelsize / 2 + 24,
        x: this.cs.xaxis.start + this.cs.xaxis.length / 2,
        t: this.cs.xaxis.label,
        opts: {fill: '#000', font: this.cs.xaxis.labelsize + 'px Arial', 'font-weight': 'bold'}
      });
    }
  /*    tick_values = this.get_ticks(yaxis);*/
  };
  /* jshint +W074 */
  Raphael.fn.cs_get_ticks = function (axis) {
    var ticks = [], log_min_value, log_max_value, gap, x, v, lab, mu, x2, v2, mnu, npts, i, p, rounded_min_value, rounded_max_value, lab2, off, t;
    if (axis.scaling === 'log') {
      log_min_value = Math.floor(Math.log(axis.minvalue) / Math.log(10));
      log_max_value = Math.ceil(Math.log(axis.maxvalue) / Math.log(10));
      gap = Math.pow(10, axis.major);
      for (x = log_min_value; x <= log_max_value; x += axis.major) {
        v = Math.pow(10, x);
        lab = v;
        if (axis.label_style === 'scientific' || (axis.label_style === 'best_scientific' && Math.abs(x) > 3)) {
          lab = '10^' + x + axis.label_suffix;
        }
        mu = this.cs_scale(axis, v);
        if (mu !== '+' && mu !== '-') {
          ticks.push({pos: mu, label: lab, line: axis.line });
        }
        if (axis.minor) {
          for (x2 = axis.minor; x2 < gap; x2 += axis.minor) {
            v2 = x2 * v;
            mnu = this.cs_scale(axis, v2);
            if (mnu !== '+' && mnu !== '-') {
              ticks.push({pos: mnu });
            }
          }
        }
      }
      return ticks;
    }
    if (axis.scaling === 'discrete') {
      npts = axis.values.length;
      for (i = npts; i; i--) {
        p = axis.values[i - 1];
        ticks.push({ pos: this.cs_scale(axis, p), label: p });
      }
      return ticks;
    }// linear scale
    rounded_min_value = Math.floor(axis.minvalue / axis.major);
    rounded_max_value = Math.ceil(axis.maxvalue / axis.major);
    for (t = rounded_min_value; t <= rounded_max_value; t++) {
      x = t * axis.major;
      mu = this.cs_scale(axis, x);
      if (mu !== '+' && mu !== '-') {
        lab2 = x;
        if (axis.label_scale) {
          lab2 /= axis.label_scale;
        }
        if (axis.label_style === 'scientific' || (axis.label_style === 'best_scientific' && Math.abs(x) > 3)) {
          lab2 = parseFloat(lab2).toExponential(axis.label_dp) + axis.label_suffix;
        } else {
          lab2 = parseFloat(lab2).toFixed(axis.label_dp) + axis.label_suffix;
        }
        ticks.push({pos: mu, label: lab2, line: axis.line });
      }
      if (axis.minor) {
        off = axis.major / axis.minor;
        for (x2 = 1; x2 < axis.minor; x2++) {
          v2 = x + x2 * off;
          mnu = this.cs_scale(axis, v2);
          if (mnu !== '+' && mnu !== '-') {
            ticks.push({pos: mnu });
          }
        }
      }
    }
    return ticks;
  };

  Raphael.fn.cs_scale_x = function (x) {
    return this.cs_scale(this.cs.xaxis, x);
  };
  Raphael.fn.cs_scale_y = function (y) {
    return this.cs_scale(this.cs.yaxis, y);
  };
  Raphael.fn.cs_scale = function (axis, v) {
    var val = '', o2 = 0, x = v;
    if (axis.dir === '-') {
      if (axis.scaling === 'discrete') {
        if (typeof (v) === 'object') {
          x = v.val;
          if (typeof (v.off) !== 'undefined') {
            o2 = v.off;
          }
        }
        if (Math.abs(o2) < 1) {
          o2 *= axis.mult;
        }
        return axis.end - axis.mult * (axis.invert[x] + 0.5) - o2;
      }
      if (axis.scaling === 'log' && v <= 0) { return '+'; }
      val = axis.start + axis.mult * (axis.scaling === 'log' ? Math.log(axis.maxvalue / v) : (axis.maxvalue - v));
    } else {
      if (axis.scaling === 'discrete') {
        if (typeof (v) === 'object') {
          x = v.val;
          if (typeof (v.off) !== 'undefined') {
            o2 = v.off;
          }
        }
        if (Math.abs(o2) < 1) {
          o2 *= axis.mult;
        }
        return axis.start + axis.mult * (axis.invert[x] + 0.5) + o2;
      }
      if (axis.scaling === 'log' && v <= 0) {
        return '-';
      }
      val = axis.start + axis.mult * (axis.scaling === 'log' ? Math.log(v / axis.minvalue) : (v - axis.minvalue));
    }
    return (val < axis.start - 0.5) ? '-' : ((val > axis.end + 0.5) ? '+' : val);
  };

  Raphael.fn.cs_shape = function (sh, x, y, radius) {
    var path_string, o2 = radius, o;
    if (typeof (sh) === 'object') {
      o = this.path(sh.path).translate(x, y);
      if (sh.scale_factor) {
        o.scale(radius / sh.scale_factor);
      } else {
        o.scale(radius);
      }
      return o;
    }
    switch (sh) {
    case 'square':
      o2 *= Math.sqrt(Math.PI) / 2;
      path_string = 'm-1 -1l0 2l2 0l0 -2';
      break;
    case 'diamond':
      o2 *= Math.sqrt(Math.PI / 2);
      path_string = 'm-1 0l1 1l1 -1l-1 -1';
      break;
    case 'cross':
    case '+':
      o2 *= Math.sqrt(Math.PI / 40);
      path_string = 'm-3 1l2 0l0 2l2 0l0 -2l2 0l0 -2l-2 0l0 -2l-2 0l0 2l-2 0 l';
      break;
    case 'x':
      o2 *= Math.sqrt(Math.PI / 20);
      path_string = 'm-3 1l2 0l0 2l2 0l0 -2l2 0l0 -2l-2 0l0 -2l-2 0l0 2l-2 0 l';
      break;
    case '<':
    case 'left':
      path_string = 'm-1.904625 0 2.856938 1.649454 0 -3.298908';
      break;
    case 'right':
    case '>':
      path_string = 'm1.904625 0 -2.856938 1.649454 0 -3.298908';
      break;
    case 'v':
    case 'V':
    case 'down':
      path_string = 'm0 -1.34677 1.16634 0.67339 -1.16634 0.667339';
      break;
    case '^':
    case 'up':
      path_string = 'm0 1.34677 1.16634 -0.67339 -1.16634 -0.667339';
      break;
    default:
      return this.circle(x, y, radius);
    }
    return this.path('M' + x + ' ' + y + path_string.replace(/(-?\d+(\.\d+)?)/g, function ($1) {
      return $1 * o2;
    }) + 'z');
  };
  Raphael.fn.cs_add_points = function (pts, defs) {
    var t = this.set(),
        defaults = {template: '[[label]] - [[value]]\n([[x]],[[y]])', radius: 5, edge: undefined,
                    opacity: 0.5, href_external: false, href: false, col: '#000', shape: 'circle',
                    show_label: false, popup: true, 'stroke-width': 1 },
        o = this,
        defo, pt, x, y, c, title, txl, pr, w, h, xo, yo, xalign, yalign, xpos, ypos,
        mout, mover, i;
    if (typeof (defs) === 'object') {
      for (defo in defs) {
        if (typeof (defs[defo]) !== 'undefined') {
          defaults[defo] = defs[defo];
        }
      }
    }
    mover = function () {
      o.cs_draw_balloon({ x: this.attrs.cx, y: this.attrs.cy, radius: this.attrs.r, t: this.attrs.balloontext });
    };
    mout  = function () {
      if (o.cs.popup_text) {
        o.cs.popup_text.remove();
        o.cs.popup_text = null;
        o.cs.popup_box.remove();
      }
    };
    for (i = pts.length; i; i--) {
      pt = pts[i - 1];
      x = this.cs_scale_x(pt.x);
      y = this.cs_scale_y(pt.y);
      if (x === '-' || y === '-' || x === '+' || y === '+') {
        return null;
      }
      for (pr in defaults) {
        if (typeof (defaults[pr]) !== 'function' && typeof (pt[pr]) === 'undefined') {
          pt[pr] = defaults[pr];
        }
      }
      c = this.cs_shape(pt.shape, x, y, pt.radius);
      if (typeof (pt.edge) === 'undefined') {
        pt.edge = pt.col; // Colour edge same as centre!
      }
      c.attr({ opacity: pt.opacity, fill: pt.col, stroke: pt.edge, 'stroke-width': pt['stroke-width'] });
      c.attrs.cx = x;
      c.attrs.cy = y;
      c.attrs.r  = pt.radius;
      if (pt.href) {
        c.attrs.href = pt.href;
        c.attrs.href_external = pt.href_external;
      }
      title = pt.template.
        replace(/\[\[value\]\]/g, pt.value).
        replace(/\[\[label\]\]/g, pt.label).
        replace(/\[\[x\]\]/g, this.cs_format_x(pt.x)).
        replace(/\[\[y\]\]/g, this.cs_format_y(pt.y)).
        replace(/^ - /, '');
      if (pt.show_label) {
        txl = this.cs_add_text({ raw: 1, x: x, y: y, t: pt.label });
        w = txl.getBBox().width + Math.sqrt(3 / 4) * pt.radius;
        h = txl.getBBox().height + pt.radius / 2;
        txl.remove();
        // Compute direction...
        xo = x - this.cs.xaxis.start;
        yo = y - this.cs.yaxis.start;
        if (xo < w || (xo > this.cs.xaxis.length / 2 && xo < this.cs.xaxis_length - w)) { // draw on right hand side
          xalign = 'left';
          xpos = x + pt.radius * Math.sqrt(3 / 4);
        } else {
          xalign = 'right';
          xpos = x - pt.radius * Math.sqrt(3 / 4);
        }
        if (yo < h || (yo > this.cs.yaxis.lenght / 2 && yo < this.cs.yaxis_length - h)) {
          yalign = 'top';
          ypos   = y + pt.radius / 2;
        } else {
          yalign = 'bottom';
          ypos   = y - pt.radius / 2;
        }
        this.cs_add_text({ raw: 1, x: xpos, y: ypos, t: pt.label, align: xalign, valign: yalign, opts: {'font-size': '12px', 'font-weight': 'bold'} });
      }
      if (pt.href) {
        c.attr('href', pt.href);
        if (pt.href_external) {
          c.attr('target', 'new');
        }
      }
      if (pt.click) {
        c.click(pt.click);
      }
      if (pt.popup) {
        c.attrs.balloontext = title;
        c.mouseover(mover);
        c.mouseout(mout);
      }
      t.push(c);
    }
    return t;
  };

  Raphael.fn.cs_add_image = function (pars) {
    var x = pars.x, y = pars.y, h = pars.h, w = pars.w, l, r, tl, t, b, tb;
    if (pars.l && pars.r) { // base this on l, r, align
      l = pars.l;
      r = pars.r;
      if (!pars.raw) {
        l = this.cs_scale_x(l);
        r = this.cs_scale_x(r);
      }
      if (r < l) {
        tl = l;
        l = r;
        r = tl;
      }
      x     = l;
      w     = (r - l);
    } else { // base this on x, w, align
      if (!pars.raw) {
        x = this.cs_scale_x(x);
      }
      if (w < 0) {
        w *= -this.cs.xaxis.length;
      }
      if (pars.align === 'right') {
        x -= w;
      }
      if (pars.align === 'center') {
        x -= 0.5 * w;
      }
    }
    if (pars.t && pars.b) { // base this on l, r, align
      t = pars.t;
      b = pars.b;
      if (!pars.raw) {
        t = this.cs_scale_x(t);
        b = this.cs_scale_x(b);
      }
      if (t < b) {
        tb = b;
        b = t;
        t = tb;
      }
      y     = t;
      h     = (b - l);
    } else { // base this on y, h, valign
      if (!pars.raw) {
        y = this.cs_scale_y(y);
      }
      if (h < 0) {
        h *= -this.cs.yaxis.length;
      }
      if (pars.valign === 'top') {
        y -= h;
      }
      if (pars.valign === 'center') {
        y -= 0.5 * h;
      }
    }
    t = this.image(pars.name,  x, y, w, h);
    if (pars.opts) {
      t.attr(pars.opts);
    }
    return t;
  };

  Raphael.fn.cs_add_text = function (pars) {
    var pad, t;
    if (pars.raw) {
      t = this.text(pars.x, pars.y, pars.t.toString());
    } else {
      t = this.text(this.cs_scale_x(pars.x), this.cs_scale_y(pars.y), pars.t.toString());
    }
    if (pars.opts) {
      t.attr(pars.opts);
    }
    pad = pars.pad ? pars.pad : 0;
    if (pars.align === 'right') {
      t.translate(-t.getBBox().width / 2-pad, 0);
    }
    if (pars.align === 'left') {
      t.translate(t.getBBox().width / 2+pad, 0);
    }
    if (pars.valign === 'top') {
      t.translate(0, t.getBBox().height+pad / 2);
    }
    if (pars.valign === 'bottom') {
      t.translate(0, -t.getBBox().height-pad / 2);
    }
  /*    if (pars.rot) {
      t.rotate(pars.rot);
    } */
    return t;
  };

  Raphael.fn.cs_contrast = function (col) {
    var c = this.raphael.getRGB(col);
    return  (c.r * c.r * 241 + c.g * c.g * 691 + c.b * c.b * 68) > 16900000 ? '#000' : '#fff';
  };

  Raphael.fn.cs_try_text = function (pars) {
    var pad,wid,tel=false,that=this;
    if (pars.raw) {
      wid = pars.wid ? pars.wid : (pars.end - pars.start);
    } else {
      wid = this.cs_scale_x(pars.end)-this.cs_scale_x(pars.start);
    }
    pad = pars.pad ? pars.pad : 0;
    wid -= 2*pad;
    $.each( pars.txts, function( i, txt ) {
      var t,w;
      if (pars.raw) {
        t = that.text(pars.x, pars.y, txt.toString());
      } else {
        t = that.text(that.cs_scale_x(pars.x), that.cs_scale_y(pars.y), txt.toString());
      }
      w = t.getBBox().width;
      t.remove();
      if( w < wid ) {
        pars.t = txt;
        tel = that.cs_add_text( pars );
        return false;
      }
    });
    return tel;
  };

  Raphael.fn.cs_lolight = function (line) {
    line.attr('stroke-width', 1);
    line.attrs.handles.hide();
    if (line.attrs.legend) {
      line.attrs.legend.attr('stroke-width', 1);
    }
    if (this.popup_text) {
      this.popup_text.remove();
      this.popup_text = null;
      this.popup_box.remove();
    }
  };

  Raphael.fn.cs_hilight = function (line) {
    var dp = line.attrs.data_pts, rot = 30, mx = Math.cos(rot * Math.PI / 180), n  = dp.length, my = Math.sin(rot * Math.PI / 180), i, t, txt, tn, w, dy, dx, ofx, ofy, ro, tx, ty;
    if (this.cs.line) {
      this.cs_lolight(this.cs.line);
    }
    if (line.attrs.legend) {
      line.attrs.legend.attr('stroke-width', 4);
    }
    rot = 30;
    mx = Math.cos(rot * Math.PI / 180);
    n  = dp.length;
    my = Math.sin(rot * Math.PI / 180);
    for (i = dp.length; i; i--) {
      t = dp[i - 1];
      line.attrs.handles.push(this.circle(t.xp, t.yp, 6).attr({fill: line.attrs.colour, stroke: line.attrs.colour}));
      txt = '(' + t.x + ',' + t.y + ')';
      tn = this.text(t.xp, t.yp, txt).attr({fill: this.cs.background, stroke: this.cs.background, 'stroke-width': 4});
      w = tn.getBBox().width + 20;
      dy = -1;
      dx = 1;
      if (t.xp + mx * w < this.cs.xaxis.end) {
        if (i < n && t.yp > dp[i].yp) {
          dy = 1;
        }
      } else {
        dx = -1;
        dy = 1;
        if (i > 1 && dp[i - 2].yp > t.yp) {
          dy = -1;
        }
      }
      ofx = mx * w / 2 * dx;
      ofy = my * w / 2 * dy;
      ro  = dx === -1 ? -rot * dy : rot * dy;
      tn.rotate(ro, false);
      tn.translate(ofx, ofy);
      line.attrs.handles.push(tn);
      line.attrs.handles.push(this.text(t.xp, t.yp, txt).rotate(ro, false).translate(ofx,ofy).attr({fill: '#000', 'stroke-width': 0.1, stroke: '#000'}));
    }
    tx = (line.attrs.data_pts[Math.floor(n / 2)].xp + line.attrs.data_pts[Math.ceil(n / 2)].xp) / 2;
    ty = (line.attrs.data_pts[Math.floor(n / 2)].yp + line.attrs.data_pts[Math.ceil(n / 2)].yp) / 2;
    line.attr('stroke-width', 4);
  //        alert('tx '+tx+' '+ty);
    this.cs_draw_balloon({ x: tx, y: ty, radius: 1, t: line.attrs.balloontext });
    line.attrs.handles.show().toFront();
    if (this.notIE) {
      line.toFront();
    }
    this.cs.line = line;
  };
  Raphael.fn.cs_format_x = function (x) { return this.cs_format(this.cs.xaxis, x); };
  Raphael.fn.cs_format_y = function (y) { return this.cs_format(this.cs.yaxis, y); };
  Raphael.fn.cs_format = function (axis, v) {
    if (axis.scaling === 'discrete') {
      if (typeof (v) === 'object') {
        return v.val;
      }
      return v;
    }
    return parseFloat(v).toFixed( axis.precision );
  };

  Raphael.fn.cs_add_line = function (pars) {
    var n = pars.pts.length, t, i, dp = [], x, o = this;
    if (pars.raw) {
      for (i = 0; i < n; i += 2) {
        dp.push({ x: this.cs_format_x(pars.pts[i]), y: this.cs_format_y(pars.pts[i + 1]), xp: pars.pts[i], yp: pars.pts[i + 1] });
      }
    } else {
      for (i = 0; i < n; i += 2) {
        dp.push({ x: this.cs_format_x(pars.pts[i]), y: this.cs_format_y(pars.pts[i + 1]),
          xp: this.cs_scale_x(pars.pts[i]),
          yp: this.cs_scale_y(pars.pts[i + 1])
          });
      }
    }
    n = dp.length;
    x = 'M' + dp[0].xp + ' ' + dp[0].yp;
    for (i = 1; i < n; i++) {
      x += 'L' + dp[i].xp + ' ' + dp[i].yp;
    }

    t = this.path(x).attr({stroke: pars.stroke});
    if (pars.opts) {
      t.attr(pars.opts);
    }
    if (pars.label) {
      t.attrs.balloontext = pars.label;   /* Label to draw on popup balloon */
      t.attrs.data_pts    = dp;           /* Store the data points as a 4-tuple, (x,y) <- formatted x & y; (xp,yp) <- raw x & y */
      t.attrs.handles     = this.set();
      t.attrs.colour      = pars.stroke;  /* Store the colour of the line */

      t.attrs.handles.hide();
      t.mouseover(function () { o.cs_hilight(this); });
    }
    return t; // Returns the line itself...
  };

  Raphael.fn.cs_add_poly = function (pars) {
    var n = pars.pts.length, t,  i,  x;
    if (pars.raw) {
      x = 'M' + pars.pts[0] + ' ' + pars.pts[1];
      for (i = 2; i < n; i += 2) {
        x += 'L' + pars.pts[i] + ' ' + pars.pts[i + 1];
      }
      x += 'z';
      t = this.path(x).attr({fill: pars.fill, stroke: pars.stroke});
    } else {
      x = 'M' + this.cs_scale_x(pars.pts[n - 2]) + ' ' + this.cs_scale_y(pars.pts[n - 1]);
      for (i = 0; i < n; i += 2) {
        x += 'L' + this.cs_scale_x(pars.pts[i]) + ' ' + this.cs_scale_y(pars.pts[i + 1]);
      }
      x += 'z';
      t = this.path(x).attr({fill: pars.fill, stroke: pars.stroke});
    }
    if (pars.opts) {
      t.attr(pars.opts);
    }
    return t;
  };

  Raphael.fn.cs_draw_balloon = function (pars) {
    var w, h, draw_flag, xoff, yoff, str;
    if (this.cs.popup_text) {
      this.cs.popup_text.remove();
      this.cs.popup_text = null;
      this.cs.popup_box.remove();
    }
    this.cs.popup_text = this.text(pars.x, pars.y, pars.t);
    draw_flag = pars.x - this.cs.xaxis.start > this.cs.xaxis.length / 2;
    w = this.cs.popup_text.getBBox().width;
    h = this.cs.popup_text.getBBox().height;
    xoff = pars.radius + 40 + w / 2;
    yoff = -10;

    if (draw_flag) {
      xoff *= -1;
    }
    if (pars.y - h / 2 - 10 < this.cs.yaxis.start) {
      yoff = -pars.y + 10 + h / 2 + this.cs.yaxis.start;
    }
    if (pars.y + h / 2 + 10 > this.cs.yaxis.end) {
      yoff = pars.y - this.cs.yaxis.end - h / 2;
    }
    this.cs.popup_text.translate(xoff, yoff);
    str = 'M' + (pars.x + (draw_flag ? -1 : 1) * pars.radius) + ' ' + pars.y;
    if (draw_flag) {
      str += ' l -35 ' + (4 + yoff) + ' l 0 ' + (h / 2 - 4) + ' a5 5 0 0 1 -5 5 l -' + w + ' 0 a5 5 0 0 1 -5 -5 l 0 -' +
             h + ' a 5 5 0 0 1 5 -5 l ' + w + ' 0 a 5 5 0 0 1 5 5 l 0 ' + (h / 2 - 4) + ' z';
    } else {
      str += ' l 35 ' + (4 + yoff) + ' l 0 ' + (h / 2 - 4) + ' a5 5 0 0 0 5 5 l ' + w + ' 0 a5 5 0 0 0 5 -5 l 0 -' +
             h + ' a 5 5 0 0 0 -5 -5 l -' + w + ' 0 a 5 5 0 0 0 -5 5 l 0 ' + (h / 2 - 4) + ' z';
    }
    this.cs.popup_box = this.path(str).attr({ stroke: '#000', fill: '#fff'});
    this.cs.popup_box.insertBefore(this.cs.popup_text);
  };

  if($.metadata){
    $('.cs_autoload:visible').livequery(function () {
      var n   = $(this),
          w   = n.width(),
          h   = n.height(),
          md  = n.metadata(),
          url = md.data_url,
          ot  = md.type;
      n.removeClass('cs_autoload');
      $.getJSON(url, {}, function (resp) {
        (new Chartsmith[ot](n, resp, w, h)).render();
      });
    });
  }
}(jQuery));
