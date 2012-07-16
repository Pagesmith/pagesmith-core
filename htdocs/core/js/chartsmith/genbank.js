/*globals Raphael: true, Chartsmith: true, console: true */
/*jslint continue:true*/ // Required so can exit loops early! more Perlish code
/*
  Prototype extension to generate repeated strings!
*/

Chartsmith.Genbank = function (dom_node, raw_json, dom_node_width ) {
  var j, type, f;
  this.dom_node_width = dom_node_width || dom_node.width;
  this.dom_node       = dom_node;
  this.dom_id         = dom_node.attr('id');
  this.width          = this.dom_node_width - 10;
  this.length         = raw_json.length;
  // Set up render order and features array...
  this.feature_sets   = {};
  this.render_order   = [];
  this.stylesheet     = raw_json.render_features;
  this.tracks         = [];
  this.gbimg          = 0;
  this.diagonal       = 0;
  for (j = raw_json.render_order.length; j; j) {
    j--;
    type = raw_json.render_order.shift();
    this.render_order.push(type);
    this.feature_sets[type] = { type: type, features: [] };
  }
  for (j = raw_json.features.length; j; j) {
    j--;
    f   = raw_json.features[j];
    type = f.tag;
    if (f.attr.standard_name && this.feature_sets[f.attr.standard_name[0]]) {
      type = f.attr.standard_name[0];
      this.feature_sets[type].type = f.tag;
    }
    if (!this.feature_sets[type]) {
      this.render_order.push(type);
      this.feature_sets[type] = { type: type, features: [] };
    }
    this.feature_sets[type].features.push(f);
  }
  return;
};

Chartsmith.Genbank.prototype = {
  filter_features: function () {
    var j, type, fs, renderer, f, new_features, exclusion_hash, k;
    for (j = this.render_order.length; j; j) {
      j--;
      type = this.render_order[j];
      fs = this.feature_sets[type];
      if (!fs.features.length) { // No features so skip...
        continue;
      }
      renderer = this.stylesheet[fs.type]; // If named features only and name doesn't map skip!
      if (!renderer) { // No style so don't display!
        fs.features = [];
        continue;
      }
      // Filter out features!!!
      if (renderer.named_features_only && !renderer.named_features[type]) {
        fs.features = [];
        continue;
      }
      if (renderer.exclude_features) { // Now if exclude features is set remove features which are in list!
        new_features   = [];
        exclusion_hash = {};
        for (k = renderer.exclude_features.length; k; k) {
          k--;
          exclusion_hash[renderer.exclude_features[k]] = 1;
        }
        for (k = fs.features.length; k; k) {
          k--;
          if (!(fs.features[k].attr.standard_name  && exclusion_hash[fs.features[k].attr.standard_name[0]])) {
            new_features.unshift(fs.features[k]);
          }
        }
        fs.features = new_features;
      }
    }
  },
  process_features: function () {
    var tp = new Raphael(0, 0, 1, 1), j, type, fs, k, f, renderer;
    // Now do a post compute phase which only computes the label, and width, the type and colour of glyph for each features
    for (j = this.render_order.length; j; j) {
      j--;
      type = this.render_order[j];
      fs = this.feature_sets[type];
      if (!fs.features.length) {
        continue;
      }
      // Now we can do some post compute! we need to add glyph type and colour to each glyph
      // Compute label (and attach) and finally attach raw text width!
      renderer = this.stylesheet[fs.type];
      for (k = fs.features.length; k; k) {
        k--;
        f = fs.features[k];
        if (renderer.named_features && renderer.named_features[type]) {
          f.glyph = renderer.named_features[type].glyph;
          f.color = renderer.named_features[type].bgcolor;
        } else {
          f.glyph = renderer.glyph;
          f.color = renderer.bgcolor;
        }
        f.label = f.attr.standard_name ? f.attr.standard_name[0] : (f.attr.gene ? (type === 'gene' || type === 'CDS' ? f.attr.gene[0] : f.attr.gene[0] + ' ' + type) : '');
        f.label_width = tp.text(0, 0, f.label).attr({'font-size': '10px'}).getBBox(1).width;
      }
    }
    tp.remove();
    /* At this point we have computed all the meta information about the features */
  },

  place_features: function () {
    // Now we compute the positions of all features relative to their tracks...
    var track_y = 0, j, fs, k, f, bump = new Chartsmith.Bump({ width: this.width, start: 0, end: this.length }), type, renderer, t;
    this.tracks = [];
    for (j = this.render_order.length; j; j) {
      j--;
      type = this.render_order[j];
      fs = this.feature_sets[type];
      if (!fs.features.length) {
        continue;
      }
      renderer = this.stylesheet[fs.type]; // If named features only and name doesn't map skip!
      // Now bump!
      bump.reset();
      for (k = fs.features.length; k; k) {
        // FILTER FEATURES HERE....
        k--;
        f = fs.features[k];
        if (renderer.named_features && renderer.named_features[type]) {
          f.glyph = renderer.named_features[type].glyph;
          f.color = renderer.named_features[type].bgcolor;
        } else {
          f.glyph = renderer.glyph;
          f.color = renderer.bgcolor;
        }
        t = bump.add_feature(f.start, f.end, f.label_width);
        if (t >= 0) {
          f.track = track_y + t;
        } else {
          // We need to flag this as "undrawn"....
          f.track = -1;
        }
      }
      for (k = 0; k < bump.height; k) {
        this.tracks.push(track_y + k);
        k++;
      }
      track_y += bump.height;
    }
  },

  resize_image: function () {
    // Now resize the image!
    this.dom_node.css({height: 50 + this.tracks.length * 20 });
    this.gbimg = new Raphael(this.dom_id, this.dom_node_width );
    this.gbimg.cs_init({
      object: this.dom_id,
      margins: { top: 5, right: 5, left: 5, bottom: 5 },
      xaxis: { minvalue: 0, maxvalue: this.length, scaling: 'linear', minor: 1, major: 1000, line: '#ccc', label: 'seq region', axis_pos: 'above' },
      yaxis: { minvalue: 1, maxvalue: 1000,  scaling: 'discrete', line: '#ccc', values: this.tracks, axis_pos: 'left', hide: 1 }
    });
    this.diagonal = this.gbimg.cs.yaxis.mult / this.gbimg.cs.xaxis.mult / 10;
    this.dom_node.after();
  },

  render_features: function () {
    var j, fs, k, f, type;
    // diagonal - ratio of height to width - for drawing arrows
    // Now loop through the features and draw boxes for them!
    for (j = this.render_order.length; j; j) {
      j--;
      type = this.render_order[j];
      fs   = this.feature_sets[type];
      if (!fs.features.length) {
        continue;
      }

      for (k = fs.features.length; k; k) {
        k--;
        f = fs.features[k];
        this.gbimg.cs_add_text({
          x: f.start,
          y: {val: f.track, off: -0.2},
          align: 'left',
          valign: 'bottom',
          t: f.label,
          opts: {fill: 'black', 'font-size': '10px'}
        });
        this.gbimg.cs_add_line({
          stroke: '#666',
          pts: [ f.start, { val: f.track, off: -0.3 }, f.end, { val: f.track, off: -0.3 } ]
        }).attr('stroke-dasharray', '- ');
        switch (f.glyph) {
        case 'arrow':
          this.draw_arrow(f);
          break;
        case 'transcript2':
          this.draw_transcript2(f);
          break;
        default:
          this.draw_generic(f);
          break;
        }
      }
    }
  },
  draw_arrow: function (f) {
    var l, s, e, st;
    for (l = f.loc.length; l; l) {
      l--;
      s = f.loc[l][0];
      e = f.loc[l][1];
      st = f.loc[l][2];
      if (st > 0) {
        this.gbimg.cs_add_line({
          pts: [ e - this.diagonal, {val: f.track, off: -0.4}, e, {val: f.track, off: -0.3}, e - this.diagonal, {val: f.track, off: -0.2} ],
          fill: f.color,
          stroke: 'black'
        });
      } else {
        this.gbimg.cs_add_line({
          pts: [ s + this.diagonal, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.3}, s + this.diagonal, {val: f.track, off: -0.2} ],
          fill: f.color,
          stroke: 'black'
        });
      }
    }
  },
  draw_transcript2: function (f) {
    var l, s, e, st, pts;
    for (l = f.loc.length; l; l) {
      l--;
      s = f.loc[l][0];
      e = f.loc[l][1];
      st = f.loc[l][2];
      pts = [];
      if ((st < 0) && (l === 0)) { // This is the lh end...
        if (s + this.diagonal > e) {
          pts = [ e, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.3}, e, {val: f.track, off: -0.2} ];
        } else {
          pts = [ e, {val: f.track, off: -0.4}, s + this.diagonal, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.3}, s + this.diagonal, {val: f.track, off: -0.2}, e, {val: f.track, off: -0.2} ];
        }
      } else {
        if ((st > 0) && (l === f.loc.length - 1)) {
          if (s + this.diagonal > e) {
            pts = [ e, {val: f.track, off: -0.3}, s, {val: f.track, off: -0.4}, s,  {val: f.track, off: -0.2} ];
          } else {
            pts = [ e, {val: f.track, off: -0.3}, e - this.diagonal, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.2}, e - this.diagonal, {val: f.track, off: -0.2} ];
          }
        } else {
          pts = [ e, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.2}, e, {val: f.track, off: -0.2} ];
        }
      }
      this.gbimg.cs_add_poly({ pts: pts, fill: f.color, stroke: 'black' });
    }
  },
  draw_generic: function (f) {
    var l, s, e, st;
    for (l = f.loc.length; l; l) {
      l--;
      s = f.loc[l][0];
      e = f.loc[l][1];
      st = f.loc[l][2];
      this.gbimg.cs_add_poly({
        pts: [ e, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.4}, s, {val: f.track, off: -0.2}, e, {val: f.track, off: -0.2} ],
        fill: f.color,
        stroke: 'black'
      });
    }
  }
};
