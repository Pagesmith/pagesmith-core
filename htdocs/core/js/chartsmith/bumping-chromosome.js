/*globals Raphael: true */
/* Ideogram functionality .. */
var cs_ideogram_defaults = {
  chr:       '',
  len:       0,
  bands:     [],
  width:     0.2,
  karyo_set: [],
  start:     1,
  end:       0,
  colours: {
    gneg    : '#fff',
    gpos66  : '#808080',
    gpos50  : '#999',
    gpos75  : '#666',
    gpos100 : '#000',
    acen    : '#666',
    gvar    : '#ddd',
    stalk   : '#666',
    tip     : '#666',
    gpos33  : '#404040',
    gpos25  : '#ccc'
  },
  edge_colour:  '#000',
  empty_colour: '#eee'
};

Raphael.fn.cs_ideogram_render =  function () {
  var karyo_set = this.set(), width = this.cs_ideogram.width, name  = 'Chr ' + this.cs_ideogram.chr, end   = this.cs_ideogram.end, bands = this.cs_ideogram.bands, flag  = 0, j, start, pts, s, e, col, o;
  if (typeof (bands) !== 'undefined') {
    for (j = bands.length; j; j) {
      j--;
      start = parseInt(bands[j].start, 10);
      pts = [];
      if (end < this.cs_ideogram.start) {
        break; // SKIP IF GOT TO START!
      }
      if (start <= this.cs_ideogram.end) {
        s = start;
        e = end;
        if (s < this.cs_ideogram.start) {
          s = this.cs_ideogram.start;
        }
        if (e > this.cs_ideogram.end) {
          e = this.cs_ideogram.end;
        }
        switch (bands[j].stain) {
        case 'acen':
          pts = flag ?
                [ s, {val: name, off: -width}, e, name, s, {val: name, off: width} ] :
                [ e, {val: name, off: -width}, s, name, e, {val: name, off: width} ];
          flag = 1 - flag;
          break;
        case 'stalk':
          pts = [
            s,         {val: name, off: -width},
            (3 * s + e) / 4, {val: name, off: -width / 2},
            (s + 3 * e) / 4, {val: name, off: -width / 2},
            e,         {val: name, off: -width},
            e,         {val: name, off: width},
            (s + 3 * e) / 4, {val: name, off: width / 2},
            (3 * s + e) / 4, {val: name, off: width / 2},
            s,         {val: name, off: width}
          ];
          break;
        default:
          pts = [ s, {val: name, off: -width},  e, {val: name, off: -width},  e, {val: name, off: width},  s, {val: name, off: width}   ];
          break;
        }
        col = this.cs_ideogram.colours[bands[j].stain];
        o = this.cs_add_poly({ pts: pts, stroke: this.cs_ideogram.edge_colour, opts: { 'stroke-width': 0.5 }, fill: col });
        karyo_set.push(o);
      }
      end = start - 1;
    }
  }
  if (end > this.cs_ideogram.start) {
    e = end;
    if (e > this.cs_ideogram.end) {
      e = this.cs_ideogram.end;
    }
    o = this.cs_add_poly({
      pts: [ this.cs_ideogram.start, {val: name, off: -width},  e, {val: name, off: -width},  e, {val: name, off: width},  this.cs_ideogram.start, {val: name, off: width} ],
      stroke: this.cs_ideogram.edge_colour,
      opts: { 'stroke-width': 0.5 },
      fill: this.cs_ideogram.empty_colour
    });
    karyo_set.push(o);
  }
  this.cs_ideogram.karyo_set = karyo_set;
};

Raphael.fn.cs_ideogram_init = function (code, chr, tracks) {
  this.cs_ideogram = cs_ideogram_defaults;
  this.cs_ideogram.code  = code;
  this.cs_ideogram.chr   = chr.name;
  this.cs_ideogram.bands = chr.bands;
  this.cs_ideogram.len   = parseInt(chr.len, 10);
  this.cs_ideogram.start = 1;
  this.cs_ideogram.end   = this.cs_ideogram.len;
  this.cs_ideogram.tracks = tracks;
};

Raphael.fn.cs_ideogram_generate_axis = function (extent) {
  this.cs_ideogram.len = this.cs_ideogram.end - this.cs_ideogram.start + 1;
  var len = this.cs_ideogram.len, major = Math.pow(10, Math.floor(Math.log(len) / Math.LN10)), xaxis_conf, pars;
  if (len / major < 5) {
    major *= 0.5;
  }
  xaxis_conf = {
    minvalue:     this.cs_ideogram.start - extent * major,
    maxvalue:     this.cs_ideogram.end   + extent * major,
    dir:          '+',
    scaling:      'linear',
    line:         '#ccc',
    label:        '',
    axis_pos:     'below',
    major:        major,
    minor:        5,
    label_scale:  1e6,
    label_dp:     0,
    label_suffix: 'Mb'
  };
  if (len < 5e6) {
    xaxis_conf.label_dp = 1;
  }
  if (len < 5e5) {
    xaxis_conf.label_dp     = 0;
    xaxis_conf.label_scale  = 1e3;
    xaxis_conf.label_suffix = 'Kb';
  }
  if (len < 5e4) {
    xaxis_conf.label_dp     = 1;
  }
  if (len < 1e4) {
    xaxis_conf.label_dp     = 0;
    xaxis_conf.label_scale  = 1;
    xaxis_conf.label_suffix = '';
  }
  pars = {
    object: this.cs_ideogram.code,
    margins: { top: 5, right: 10, left: 50, bottom: 15 },
    xaxis: xaxis_conf,
    yaxis: { minvalue: 0, maxvalue: 1,  scaling: 'discrete', line: '#ccc', values: this.cs_ideogram.tracks, label: '', axis_pos: 'left' }
  };
  this.cs_init(pars);
};
