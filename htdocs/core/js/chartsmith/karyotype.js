(function(){
  'use strict';
  /*globals Raphael: true */
  /* Karyotype functionality .. */
  var cs_karyotype_defaults = {
    chromosomes: [],
    width: 0.2,
    karyo_set: [],
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
    empty_colour: '#eee',
    max_len: 0,
    valid_x: {}
  };

  Raphael.fn.cs_karyotype_render = function () {
    var karyo_set, i, width, chr, name, end, bands, flag, j, start, pts, col;
    if (!this.cs_karyotype.chromosomes.length) {
      this.text(100, 50, 'This species has no karyotype');
      return;
    }
    karyo_set = this.set();
    for (i = this.cs_karyotype.chromosomes.length; i; i) {
      i--;
      width = this.cs_karyotype.width;
      chr   = this.cs_karyotype.chromosomes[i];
      name  = chr.name;
      end   = parseInt(chr.len, 10);
      bands = chr.bands;
      flag  = 0;
      if (typeof (bands) !== 'undefined') {
        for (j = bands.length; j; j) {
          j--;
          start = parseInt(bands[j].start, 10);
          pts = [];
          switch (bands[j].stain) {
          case 'acen':
            pts = flag ?
                  [ {val: name, off: -width}, start, name, end,  {val: name, off: width}, start ] :
                  [ {val: name, off: -width}, end,   name, start, {val: name, off: width}, end   ];
            flag = 1 - flag;
            break;
          case 'stalk':
            pts = [ {val: name, off: -width / 2}, start, {val: name, off: -width / 2}, end, {val: name, off: width / 2}, end, {val: name, off: width / 2}, start ];
            break;
          default:
            pts = [ {val: name, off: -width},  start, {val: name, off: -width},  end, {val: name, off: width},  end, {val: name, off: width},  start ];
            break;
          }
          col = this.cs_karyotype.colours[bands[j].stain];
          karyo_set.push(this.cs_add_poly({ pts: pts, stroke: this.cs_karyotype.edge_colour, opts: { 'stroke-width': 0.5 }, fill: col }));
          end = start - 1;
        }
      }
      if (end > 1) {
        karyo_set.push(this.cs_add_poly({
          pts: [ {val: name, off: -width},  1, {val: name, off: -width},  end, {val: name, off: width},  end, {val: name, off: width},  1 ],
          stroke: this.cs_karyotype.edge_colour,
          opts: { 'stroke-width': 0.5 },
          fill: this.cs_karyotype.empty_colour
        }));
      }
    }
    this.cs_karyotype.karyo_set = karyo_set;
  };

  Raphael.fn.cs_karyotype_draw_features = function (features, options) {
    var pts = [], n_drawn = 0, n_not_drawn = 0, i, g, s, t_pts;
    for (i = features.length; i; i) {
      i--;
      g = features[i];
      if (this.cs_karyotype.valid_x[g.chr]) {
        n_drawn++;
        s = parseInt(g.strand, 10);
        pts.push({ x: { val: g.chr, off: 0.25 * s }, y: (parseInt(g.start, 10) + parseInt(g.end, 10)) / 2, shape: s < 0 ? '>' : '<', label: g.label, value: g.id });
      } else {
        n_not_drawn++;
      }
    }
    t_pts = this.cs_add_points(pts, options);
    return { pts: t_pts, drawn: n_drawn, not_drawn: n_not_drawn };
  };

  Raphael.fn.cs_karyotype_init =  function (code, resp) {
    var x_values = [], max_len = 0, i, l, major, yaxis_conf, pars;
    this.cs_karyotype = cs_karyotype_defaults;
    this.cs_karyotype.chromosomes = resp;
    this.cs_karyotype.max_len = 0;
    this.cs_karyotype.valid_x = [];
    if (!resp.length) {
      return;
    }
    for (i = resp.length; i; i) {
      i--;
      this.cs_karyotype.valid_x[resp[i].name] = 1;
      x_values.unshift(resp[i].name);
      l = parseInt(resp[i].len, 10);
      if (l > max_len) {
        max_len = l;
      }
    }
    if (max_len > 0) {
      major = Math.pow(10, Math.floor(Math.log(max_len) / Math.LN10));
      if (max_len / major < 5) {
        major *= 0.5;
      }
      yaxis_conf = {
        minvalue:     -major / 10,
        maxvalue:     max_len + major / 10,
        dir:          '+',
        scaling:      'linear',
        line:         '#ccc',
        label:        'Basepairs',
        axis_pos:     'left',
        major:        major,
        minor:        5,
        label_scale:  1e6,
        label_dp:     0,
        label_suffix: 'Mb'
      };
      if (max_len < 5e6) {
        yaxis_conf.label_dp = 1;
      }
      if (max_len < 5e5) {
        yaxis_conf.label_dp     = 0;
        yaxis_conf.label_scale  = 1e3;
        yaxis_conf.label_suffix = 'Kb';
      }
      if (max_len < 5e4) {
        yaxis_conf.label_dp     = 1;
      }
      if (max_len < 1e4) {
        yaxis_conf.label_dp     = 0;
        yaxis_conf.label_scale  = 1;
        yaxis_conf.label_suffix = '';
      }
      pars = {
        object: code,
        margins: { top: 10, right: 10, left: 50, bottom: 40 },
        xaxis: { minvalue: 0, maxvalue: 1,  scaling: 'discrete', line: '#ccc', values: x_values, label: 'Chromosome', axis_pos: 'below' },
        yaxis: yaxis_conf
      };
      this.cs_init(pars);
    }
    this.cs_karyotype.max_len = max_len;
  };
}());
