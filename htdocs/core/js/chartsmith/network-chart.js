(function(){
  'use strict';
  /*globals Raphael:true, console: true  */
  /**
   * Code modified from the network diagram in the Genes2Cognition Project,
   * uses mainly raphael with a little bit of jQuery thrown in for good measure
   *
   * Gets data out of arnie database
   *
   * data_stucture:
   * {
   *   proteins: [ { id: ##, name: $$$, x: #.##, y: #.##, zfin,  } ],
   *   tissues:  [ { ##: $$$ } ],
   *   stages:   [ { ##: $$$ } ],
   *   interaction: { #p_id#: { #p_id#: [ #t_id, #s_id, #t_id, #s_id ] } },
   * }
   * @author:   js5 (James Smith)
   * @version:  $Id$
   * @requires: jQuery, jQuery hashchanger, RaphaelJS
   *
   */
  /* Need the following as there is a "feature" in the IE 9 canvas which
  ** means that canvas elements can flow outside the canvas!
  **/
  function isIE9Std() {
    return document.all && document.addEventListener && !window.atob && document.compatMode==='CSS1Compat';
  }
  function intersect( a, b, c, d) {
    var den = (b.y-a.y)*(d.x-c.x) - (b.x-a.x)*(d.y-c.y), t, s;
    if( den === 0 ) { // These are parallel
      return {};
    }
    t = ((a.x-c.x)*(d.y-c.y) - (a.y-c.y)*(d.x-c.x))/den;
    s = d.x-c.x === 0 ? (a.y-c.y + (b.y-a.y)*t)/(d.y-c.y) : (a.x-c.x + (b.x-a.x)*t)/(d.x-c.x);
    return 0<=t && t<=1 && 0<=s && s<=1 ? { x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t} : {};
  }
  Pagesmith.NetworkChart = function( id, options ) {
    this.init( id, options );
  };

  Pagesmith.NetworkChart.prototype = {
    /* jshint -W072 */
    draw_arrow: function( pts, x, y, ux, uy, sf, opts ) {
      var str = 'M'+x+' '+y, l = pts.pts.length, i;
      for(i=0;i<l;i) {
        str += pts.pts[i]+(-pts.pts[i+1]*uy*sf+pts.pts[i+2]*ux*sf)+' '+
                          ( pts.pts[i+1]*ux*sf+pts.pts[i+2]*uy*sf);
        i+=3;
      }
      if( pts.fill ) {
        str += 'z';
      }
      var p = this.paper.path( str ).attr( opts );
      if( pts.fill ) {
        p.attr( {fill: opts.stroke} );
      }
      return;
    },
    /* jshint +W072 */
    init: function( obj_id, options ) {
      var self        = this;
      this.line_styles = {
        dashed:        '- ',
        dashed_dotted: '- .',
        dotted:        '. ',
        line:          ''
      };
      this.drawn_objects = 0;
      this.n_objects     = 0;
      this.drawn_connections = 0;
      this.n_connections = 0;
      this.arrow_defs     = {
        /* dash, none, plain, standard, t_shape */
        t_shape:   { fill:0, pts: [ 'm', -1, 0, 'l', 2, 0 ] },
        dash:      { fill:0, pts: [ 'm', -1, 2, 'l', 2, 0 ] },
        standard:  { fill:1, pts: [ 'l', -1, 1.5, 'l', 1, -0.5, 'l', 1, 0.5 ] },
        plain:     { fill:0, pts: [ 'm', -1, 1, 'l', 1, -1, 'l', 1, 1 ] }
      };
      this.shape_defs     = {
        circle:  { textwidth: 0.7, textheight: 0.7, valign: 'middle', align: 'center' },
        ellipse: { textwidth: 0.7, textheight: 0.7, valign: 'middle', align: 'center' },
        diamond:   { line: 'm-0.5 0l0.5 0.5l0.5 -0.5l-0.5 -0.5',
                textwidth: 0.7,
                textheight: 0.7,
                   valign: 'middle',
                    align: 'center',
                      pts:  [ [ 0.5,0], [0,0.5],[-0.5,0],[0,-0.5] ] },
        triangle:  { line: 'm-0.5 0.5l0.5 -1l0.5 1',
                textwidth: 0.6,
                textheight: 1,
                   valign: 'bottom',
                    align: 'center',
                      pts:  [ [ -0.5,  0.5],[ 0 , -0.5],[ 0.5,  0.5] ] },
        trapezoid: { line: 'm-0.5 0.5l0.25 -1l0.5 0l0.25 1l',
                textwidth: 0.9,
                textheight: 1,
                   valign: 'bottom',
                    align: 'center',
                      pts:  [ [-0.5,  0.5], [-0.25, -0.5 ] ,[ 0.25, -0.5 ],[ 0.5,  0.5] ] },
        octagon:   { line: 'm-0.5 -0.25l0 0.5l0.25 0.25l0.5 0l0.25 -0.25l0 -0.5l-0.25 -0.25l-0.5 0',
                textwidth: 0.8,
                textheight: 0.8,
                   valign: 'middle',
                    align: 'center',
                      pts:  [ [-0.5, -0.25],[-0.5, 0.25],[-0.25, 0.5],[ 0.25, 0.5],
                              [ 0.5,  0.25],[ 0.5,-0.25],[ 0.25,-0.5],[-0.25,-0.5] ] },
        hexagon:   { line: 'm-0.5 0l0.25 0.5l0.5 0l0.25 -0.5l-0.25 -0.5l-0.5 0',
                textwidth: 0.8,
                textheight: 0.8,
                   valign: 'middle',
                    align: 'center',
                      pts:  [ [-0.5,  0  ], [-0.25,-0.5 ] ,[ 0.25,-0.5] ,
                              [ 0.5,  0  ], [ 0.25, 0.5 ] ,[-0.25, 0.5]] },
        roundrectangle: { line: 'm-0.5 -0.5l1 0l0 1l0 -1',
                     textwidth: 1,
                    textheight: 1,
                        valign: 'middle',
                         align: 'center',
                           pts: [ [-0.5,-0.5], [-0.5, 0.5 ],[ 0.5,0.5], [0.5,-0.5] ] },
        rectangle: { line: 'm-0.5 -0.5l1 0l0 1l0 -1',
                textwidth: 1,
               textheight: 1,
                   valign: 'middle',
                    align: 'center',
                      pts:  [ [-0.5,-0.5], [-0.5, 0.5 ],[ 0.5,0.5], [0.5,-0.5] ] }
      };
      this.fetching_notice     = 'Fetching proteins and preparing chart data';
      this.copyright_notice    = 'Copyright Wellcome Trust Sanger Institute';
      this.include_diagnositcs = 1;
      this.MAX_ZOOM            = 40;
      this.SF                  = 100 / 2 - 10;
      this.paper               = null;
      this.DELAY               = 20;
      this.colors              = [ '#ccc', '#99f', '#fff', '#f99', '#9f9' ];
      this.borders             = [ '#999', '#00c', '#000', '#c00', '#090' ];
    // Now we have the bits which are specific to arnie....
      this.data_store          = { highlights: [] };
      this.filtered_data_store = {};
      this.filters_applied     = 0;
      this.params              = {};
      this.prev_params         = {};

      this.id                  = '';
      this.c_x                 = 0;
      this.c_y                 = 0;
      this.sc                  = 1;
      this.start_drag          = 0;
      this.prev_c_x            = 0;
      this.prev_c_y            = 0;
      this.prev_sc             = 0;
      this.ie                  = isIE9Std();
      this.chart_id            = obj_id;
      this.jq_obj              = $('#'+obj_id);
      this.WIDTH               = this.jq_obj.width();
      this.HEIGHT              = this.jq_obj.height();
      this.paper               = new Raphael( obj_id, this.WIDTH, this.HEIGHT );
      /* Put up a message at the start of the script */
      this.get_params().copy_params_to_previous();
      this.paper.text( this.WIDTH/2, this.HEIGHT/2, this.fetching_notice ).attr( {fill:'#000','font-size':24} );
      this.SF                  = ( this.WIDTH < this.HEIGHT ? this.WIDTH : this.HEIGHT ) / 2 - 10;
      this.popup_array = {};
      this.data_loaded = 0;
      $(window).on('resize',function(){ self.draw_chart();});
      window.setTimeout( function() { self._init(options); }, this.DELAY );
      return this;
    },
    align_text: function (pars) {
      var pad = 'pad' in pars ? pars.pad : 0,
          w   = 'w'   in pars ? pars.w   : 100,
          h   = 'h'   in pars ? pars.h   : 12,
          mfs = 'max_font' in pars ? pars.max_font : 12,
          fs  = mfs,
          txt = (pars.t+''),
          t   = this.paper.text(pars.x, pars.y, txt.toString()),
          rat;
      if( pars.opts ) {
        t.attr(pars.opts);
      }
      t.attr( 'font-size', fs );
      var tw = t.getBBox().width;
      var th = t.getBBox().height;
      if( tw+pad*2 > w ) {
        rat = (w-pad*2)/tw;
        fs *= rat;
        th  = th * rat;
        tw  = w-pad*2;
      }
      if( th+pad*2 > h ) {
        rat = (h-pad*2)/th;
        fs *= rat;
        tw  = tw * rat;
        th  = h-pad*2;
      }
      if( fs < mfs ) {
        t.remove();
        t = this.paper.text(pars.x, pars.y, txt.toString());
        if( pars.opts ) {
          t.attr(pars.opts);
        }
        t.attr( 'font-size', fs );
      }
      pad = pars.pad ? pars.pad : 0;
      if (pars.align === 'right') {
        t.translate( (w-tw) / 2-pad, 0);
      }
      if (pars.align === 'left') {
        t.translate( (tw-w) / 2+pad, 0);
      }
      if (pars.valign === 'top') {
        t.translate(0, (th-h)/2+pad );
      }
      if (pars.valign === 'bottom') {
        t.translate(0, (h-th)/2-pad );
      }
      return t;
    },
    _init: function( /*options*/ ) {
      window.alert( 'You need to sub-class this object' );
    },
    /* Managing parameters and highlighting */
    get_params: function( ) { // Can overwrite
    },
    patch_edge: function( node, start, end ) {
      var pts, p1, p2, l, ip;
    /* Patch the end of a line... note
       start should be in feature!
       end should be outside feature,
       node is the shape we are seeing if it is in! */
      if( ! (node.obj.shape in this.shape_defs) ) {
        return 1;
      }
      pts = this.shape_defs[ node.obj.shape ].pts;
      p1 = { x: node.x + pts[0][0]*node.w,
             y: node.y + pts[0][1]*node.h};
      for(l = pts.length;l;l) {
        l--;
        p2 = { x: node.x + pts[l][0]*node.w,
               y: node.y + pts[l][1]*node.h};
        ip = intersect( start, end, p1, p2 );
        if( 'x' in ip ) {
          start.x = ip.x;
          start.y = ip.y;
          return 1;
        }
        p1 = p2;
      }
      return 0;
      /* Don't intersect... yarg... */
      // Is start inside shape ?
    },
    copy_params_to_previous: function() { // Can overwrite
      var i;
      for( i in this.params ) {
        if( this.params.hasOwnProperty(i) ) {
          this.prev_params[i] = this.params[i];
        }
      }
      return this;
    },
    reset_highlighting: function() {
      this.data_store.highlights = [];
      return this;
    },
    highlight: function(id) {
      this.data_store.highlights.push(id);
      return this;
    },

    /* Diagnostics and decorations! */
    diagnostic_message: function () { // Can overwrite
      return 'Drawn: '+this.drawn_objects+'/'+this.n_objects+' objects and '+
        this.drawn_connections+'/'+this.n_connections+' connections';
      // Drawn: '+d_g+'/'+this.n_genes+' genes and '+d_l+'/'+this.types[this.active_key]+' lines}
    },
    add_copyright_notice: function() {
      this.paper.text( 4, this.HEIGHT-8, this.copyright_notice ).attr({
        opacity: 0.6,
        fill:'#fff',
        'font-size':10,
        'text-anchor':'start',
        'font-weight': 'bold',
        'stroke-width':4,
        'stroke':'#fff'
      });
      this.paper.text( 4, this.HEIGHT-8, this.copyright_notice ).attr({
        fill:'#000',
        'font-size':10,
        'text-anchor':'start',
        'font-weight': 'bold'
      });
      return this;
    },
    reset_chart_size: function() {
      this.c_x=0;
      this.c_y=0;
      this.sc=1;
    },
    add_navigation_panel: function() {
      var self = this;
      this.paper.circle( this.WIDTH-35, 45, 22 ).attr( { stroke:'#666','stroke-width':1,fill:'#fff'} );
      this.paper.path( 'M'+ (this.WIDTH-35) +' 25l5 10l-10 0'      ).attr(
        {cursor:'pointer',title:'up',   stroke:'#666','stroke-width':1,fill:'#000'}).click(
        function() { self.c_y -= 1/self.sc;           self.draw_chart(); } );
      this.paper.path( 'M'+ (this.WIDTH-35) +' 65l5 -10l-10 0'     ).attr(
        {cursor:'pointer',title:'down', stroke:'#666','stroke-width':1,fill:'#000'}).click(
        function() { self.c_y += 1/self.sc;           self.draw_chart(); } );
      this.paper.path( 'M'+ (this.WIDTH-15) +' 45l-10 5l0 -10'     ).attr(
        {cursor:'pointer',title:'right',stroke:'#666','stroke-width':1,fill:'#000'}).click(
        function() { self.c_x += 1/self.sc;           self.draw_chart(); } );
      this.paper.path( 'M'+ (this.WIDTH-55) +' 45l10 5l0 -10'      ).attr(
        {cursor:'pointer',title:'left', stroke:'#666','stroke-width':1,fill:'#000'}).click(
        function() { self.c_x -= 1/self.sc;           self.draw_chart(); } );
      this.paper.path( 'M'+ (this.WIDTH-30) +' 40l0 10l-10 0l0 -10').attr(
        {cursor:'pointer',title:'reset',stroke:'#666','stroke-width':1,fill:'#000'}).click(
        function() { self.reset_chart_size(); self.draw_chart(); } );
      this.paper.text( this.WIDTH-35,45, 'R'                       ).attr(
        {cursor:'pointer',title:'reset',fill:'#fff',  'font-weight':'bold'        }).click(
        function() { self.reset_chart_size(); self.draw_chart(); } );
      this.paper.circle( this.WIDTH-11, 20, 10 ).attr(
        {cursor:'pointer',title:'zoom in x5',stroke:'#666','stroke-width':1,fill:'#fff'} ).click(
        function()  {self.sc*=5;self.draw_chart();} );
      this.paper.path(   'M'+(this.WIDTH-18)+' 22l5 0l0 5l4 0l0 -5l5 0l0 -4l-5 0l0 -5l-4 0l0 5l-5 0l' ).attr(
        {title:'zoom in x5',fill:'#000','stroke-opacity':0}).click(
        function()  {self.sc*=5;self.draw_chart();} );
      this.paper.circle( this.WIDTH-26, 8, 7 ).attr(
        {cursor:'pointer',title:'zoom in x2',stroke:'#666','stroke-width':1,fill:'#fff'} ).click(
        function()  {self.sc*=2;self.draw_chart();} );
      this.paper.path(   'M'+(this.WIDTH-31)+' 10l3 0l0 3l4 0l0 -3l3 0l0 -4l-3 0l0 -3l-4 0l0 3l-3 0l' ).attr(
        {'stroke-opacity':0,title:'zoom in x2',fill:'#000'}).click(
        function()  {self.sc*=2;self.draw_chart();} );
      this.paper.circle( this.WIDTH-44, 8, 7 ).attr(
        {cursor:'pointer',title:'zoom out x2',stroke:'#666','stroke-width':1,fill:'#fff'} ).click(
        function()  {self.sc/=2;self.draw_chart();} );
      this.paper.path(   'M'+(this.WIDTH-49)+' 10l10 0l0 -4l-10 0' ).attr(
        {'stroke-opacity':0,title:'zoom out x2',fill:'#000'}).click(
        function()  {self.sc/=2;self.draw_chart();} );
      this.paper.circle( this.WIDTH-59, 20, 10 ).attr(
        {cursor:'pointer',title:'zoom out x5',stroke:'#666','stroke-width':1,fill:'#fff'} ).click(
        function()  {self.sc/=5;self.draw_chart();} );
      this.paper.path( 'M'+(this.WIDTH-66)+' 22l14 0l0 -4l-14 0').attr(
        {title:'zoom out x5',fill:'#000','stroke-opacity':0}).click(
        function()  {self.sc/=5;self.draw_chart();} );
      return this;
    },
    add_diagnostics: function(start) {
      var end = new Date();
      if( this.include_diagnositcs ) {
        var msg = '('+(this.c_x.toFixed(2))+','+(this.c_y.toFixed(2))+') x'+(this.sc.toFixed(2))+' : '+((end.getTime()-start.getTime())/1000).toFixed(2)+'sec';
        this.paper.text( this.WIDTH-4, this.HEIGHT-8, msg ).attr({
          opacity: 0.6,
          fill:'#fff',
          'font-size':10,
          'text-anchor':'end',
          'font-weight': 'bold',
          'stroke-width':4,
          'stroke':'#fff'
        });
        this.paper.text( this.WIDTH-4, this.HEIGHT-8, msg ).attr({
          fill:'#000',
          'font-size':10,
          'text-anchor':'end',
          'font-weight': 'bold'
        });
      }
      /*jsl:ignore*/
      if( console ) {
        console.log( 'Settings: ('+this.c_x+','+this.c_y+') sz='+this.sc+'; '+this.diagnostic_message()+'; Time taken: '+(end.getTime()-start.getTime())+'ms.' );
      }
      /*jsl:end*/
    },

    /* Attaching events... */
    add_click_drag: function() {
      var self = this;
      this.paper.rect( 0, 0, this.WIDTH, this.HEIGHT ).attr({stroke:'#ccc','stroke-width':1,fill:'#fff'}).toBack().dblclick(function( e ) { self.bg_dblclick( e ); } );
      return this;
    },
    attach_navigation_events: function () {
        /* This is the complex bit - we are going to add a drag select box.
        ** Can't do this with raphael objects - but can work with the
        ** underlying DIV and use jQuery to assign the mouse down/up/move/out
        ** functionality */
      var self = this;
      self.jq_obj.mousedown( function( e ){
        self.start_drag = self.get_event_loc( e );
      }).mouseout( function( e ) {
        var pos = self.get_event_loc( e );
        if( pos.x < 0 || pos.y < 0 || pos.x >= self.WIDTH || pos.Y >= self.HEIGHT ) {
          self.start_drag = 0;
          if( self.box ) {
            self.box.remove();
            self.box = 0;
          }
        }
      }).mousemove(function( e ) {
        if( self.start_drag === 0 ) {
          return;
        }
        var end_drag = self.get_event_loc( e );
        var delta_x = Math.abs(end_drag.x - self.start_drag.x);
        var delta_y = Math.abs(end_drag.y - self.start_drag.y);
        if( delta_x < 10 && delta_y < 10 && ! self.box ) {
          return;
        }
        if(self.box) {
          self.box.remove();
        }
        self.box = self.paper.rect(
          self.start_drag.x<end_drag.x?self.start_drag.x:end_drag.x,
          self.start_drag.y<end_drag.y?self.start_drag.y:end_drag.y,
          delta_x, delta_y).attr(
            {stroke:'#f00','stroke-width':1,'stroke-dasharray': '--..'}
        );
      }).mouseup( function( e ) {
        if( self.start_drag === 0 ) {
          return;
        }
        var end_drag = self.get_event_loc( e );
        var delta_x = Math.abs(end_drag.x - self.start_drag.x);
        var delta_y = Math.abs(end_drag.y - self.start_drag.y);
        if( delta_x < 10 && delta_y < 10 ) {
          self.start_drag = 0;
          if( self.box ) {
            self.box.remove();
            self.box = 0;
          }
          return;
        }
        if( self.box ) {
          self.box.remove();
          self.box = 0;
        }
        self.c_x += (self.start_drag.x + end_drag.x-self.WIDTH)/2/self.SF/self.sc;
        self.c_y += (self.start_drag.y + end_drag.y-self.HEIGHT)/2/self.SF/self.sc;
        self.start_drag = 0;
        var size_x = delta_x/2/self.SF/self.sc;
        var size_y = delta_y/2/self.SF/self.sc;
        if( size_x/self.WIDTH > size_y/self.HEIGHT ) {
          self.sc = 0.45 / self.SF / size_x * self.WIDTH;
        } else {
          self.sc = 0.45 / self.SF / size_y * self.HEIGHT;
        }
        self.draw_chart();
      });
      /* Finally attach the keyboard navigation functionality */
      /* jshint -W074 */
      $(document.documentElement).keyup(function (event) {
        var k = event.keyCode;
        var redraw = 1;
        switch( k ) {
          case 38: // up arrow
          case 104: // (up arrow) num pad 8
          case 56: // up arrow
            self.c_y -= 1/self.sc;
            break;
          case 40: // down arrow
          case 98: // (down arrow) num pad 2
          case 50: // down arrow
            self.c_y += 1/self.sc;
            break;
          case 37: // left arrow
          case 100: // (left arrow) num pad 4
          case 52: // left arrow
            self.c_x -= 1/self.sc;
            break;
          case 102: // (right arrow) num pad 6
          case 54: // right arrow
          case 39: // right arrow
            self.c_x += 1/self.sc;
            break;
          case 97: // num pad 1
          case 35: // (end) num pad 1
          case 49: // 1
            self.c_x -= 1/self.sc;
            self.c_y += 1/self.sc;
            break;
          case 99: // num pad 3
          case 34: // (page down) num pad 3
          case 51: // 3
            self.c_x += 1/self.sc;
            self.c_y += 1/self.sc;
            break;
          case 103: // num pad 7
          case 36: // (home) num pad 7
          case 55: // 7
            self.c_x -= 1/self.sc;
            self.c_y -= 1/self.sc;
            break;
          case 105: // num pad 9
          case 33: // (page up) num pad 9
          case 57: //
            self.c_x += 1/self.sc;
            self.c_y -= 1/self.sc;
            break;
          case 101: // numpad 5
          case 48: // 0
          case 45: // (insert) numpad 0
          case 82: // r
          case 12: // 5
            self.c_x =0;
            self.c_y =0;
            self.sc  =1;
            break;
          case 107: // numpad +
          case 187: // = (unshifted +)
          case 61:  // +
          case 43:  // +
            self.sc  *=2;
            break;
          case 189: // _ (unshifted -)
          case 109: // numpad -
          case 95:  // -
            self.sc  /=2;
            break;
          default:
            redraw = 0;
            break;
        }
        if( redraw ) {
          self.draw_chart( );
          return false;
        }
      });
      /* jshint +W074 */
    },
    /* General event handling! */
    bg_dblclick: function ( e ) {
      /* Double click action - zoom into point clicked */
      var e_loc = this.get_event_loc( e );
      this.c_x += ( e_loc.x - this.WIDTH/2 )/this.SF/this.sc;
      this.c_y += ( e_loc.y - this.HEIGHT/2 )/this.SF/this.sc;
      this.sc *=2;
      this.draw_chart();
    },
    object_click: function( node, e ) {
      var self = this, _p = this.get_event_loc( e ), x_p = _p.x, y_p = _p.y, z,i,
        object = this.parse_object_title( node.attr('title') ), popup_size, x_l, y_l;
      if( ! ('object_popup_dimensions' in this) ) {
        return;
      }
      if( this.popup_array[ object.id ] ) {
        return;
      }
      popup_size = this.object_popup_dimensions( object.obj );
      this.popup_array[ object.id ] = 1;
      x_l = this.g_loc[ object.id ][0];
      y_l = this.g_loc[ object.id ][1];
      if( x_p > this.WIDTH-popup_size.width) {
        x_p -= popup_size.width;
      }
      if( y_p > this.HEIGHT-popup_size.height) {
        y_p -= popup_size.height;
      }
      var popup = this.paper.set();

      popup.push( this.paper.rect( 0, 0, popup_size.width, popup_size.height ).attr({fill:'#fff',stroke:'#000','title':'Click to remove'}));
      z = this.object_popup_elements( object.obj, {x_l:x_l,y_l:y_l} );
      for( i in z ) {
        if( z.hasOwnProperty(i) ) {
          popup.push( z[i] );
        }
      }
      popup.click(function(){self.popup_array[ object.id ]=0; popup.remove();});
      popup.translate( x_p, y_p );
    },
    line_click: function( node, e ) {
      var self = this, _p = this.get_event_loc( e ), x_p = _p.x, y_p = _p.y,
          objects = this.parse_line_title( node.attr('title') ),
          x1,x2,y1,y2,x_l,y_l,size_x,size_y,popup, z,i,
          popup_key = objects.a_id +':'+objects.b_id,popup_size;
      if( !( 'line_popup_dimensions' in this ) ) {
        return;
      }
      if( this.popup_array[ popup_key ] ) {
        return;
      }
      this.popup_array[ popup_key ] = 1;
      x1 = this.g_loc[ objects.a_id ][0];
      y1 = this.g_loc[ objects.a_id ][1];
      x2 = this.g_loc[ objects.b_id ][0];
      y2 = this.g_loc[ objects.b_id ][1];
      popup_size = this.line_popup_dimensions( objects.a, objects.b );
      if( x_p > this.WIDTH - popup_size.width ) {
        x_p -=popup_size.width;
      }
      if( y_p > this.HEIGHT - popup_size.height ) {
        y_p -=popup_size.height;
      }
      x_l = (x1+x2-this.WIDTH)/2/this.SF/this.sc+this.c_x;
      y_l = (y1+y2-this.HEIGHT)/2/this.SF/this.sc+this.c_y;
      size_x  = Math.abs(x1-x2)/2/this.SF/this.sc;
      size_y  = Math.abs(y1-y2)/2/this.SF/this.sc;
      popup = this.paper.set();
      popup.push( this.paper.rect( 0, 0, popup_size.width, popup_size.height ).attr({fill:'#fff',stroke:'#000','title':'Click to remove'}));
      z = this.line_popup_elements( objects.a,objects.b, {x_l:x_l,y_l:y_l,size_x:size_x,size_y:size_y} );
      for( i in z ) {
        if( z.hasOwnProperty(i) ) {
          popup.push( z[i] );
        }
      }
      popup.click(function(){self.popup_array[ popup_key ]=0; popup.remove();});
      popup.translate( x_p, y_p );
    },

    /* Now functions to draw chart */
    draw_chart: function( ) {
      if( ! this.data_loaded ) {
        return this;
      }
      var self = this,h = this.jq_obj.height(), w = this.jq_obj.width();
      if( !this.jq_obj.is(':visible') ) { // Can't resize if not visible!
        h = this.HEIGHT;
        w = this.WIDTH;
      }
      /* First thing we do is make sure that we don't move outside the
      ** displayable box... OR zoom to far in (currently set to x40)
      */
      if( this.sc < 1 ) {
        this.sc = 1;  // sc = 1 is the
      }
      if( this.sc > this.MAX_ZOOM ) {
        this.sc = this.MAX_ZOOM;
      }
      if( this.c_x+1/this.sc > 1 ) {
        this.c_x = 1 - 1/this.sc;
      }
      if( this.c_x-1/this.sc < -1 ) {
        this.c_x = 1/this.sc - 1;
      }
      if( this.c_y+1/this.sc > 1 ) {
        this.c_y = 1 - 1/this.sc;
      }
      if( this.c_y-1/this.sc < -1 ) {
        this.c_y = 1/this.sc - 1;
      }
      /* Check to see if we have changed the location/scale if NOT
      ** then return now without redrawing */
      if( h === this.HEIGHT &&
          w === this.WIDTH &&
          this.c_x === this.prev_c_x &&
          this.c_y === this.prev_c_y &&
          this.sc === this.prev_sc &&
          !this.parameter_change() ) {
        return this;
      }
      if( h !== this.HEIGHT || w !== this.WIDTH) {
        this.WIDTH    = w;
        this.HEIGHT   = h;
        this.paper.setSize( w, h );
        this.SF       = ( w < h ? w : h ) / 2 - 10;
      }
      this.prev_sc  = this.sc;
      this.prev_c_x = this.c_x;
      this.prev_c_y = this.c_y;
      this.paper.rect(0,0,this.WIDTH,this.HEIGHT).attr({fill:'#666',opacity:0.2,cursor:'wait'});
      window.setTimeout( function() { self._draw_chart(); }, this.DELAY );
      return this;
    },
    draw_object: function(x,y,pars) {
      var self         = this,
          r            = 'r'            in pars ? pars.r            : ( 'h' in pars && 'w' in pars ? Math.min( pars.h, pars.w ) : 10 ),
          nm           = 'name'         in pars ? pars.name         : '',
          ttl          = 'title'        in pars ? pars.title        : '',
          stroke_width = 'stroke_width' in pars ? pars.stroke_width : (40+r)/50,
          fill_color   = 'color'        in pars ? pars.color        : '#ccc',
          stroke_color = 'border'       in pars ? pars.border       : '#666',
          stroke_style = 'style'        in pars ? pars.style        : '',
          shape        = 'shape' in pars && pars.shape in this.shape_defs ? pars.shape : 'rectangle',
          h            = 'h'            in pars ? pars.h            : 2*r,
          w            = 'w'            in pars ? pars.w            : 2*r,
          vratio       = this.shape_defs[shape].textwidth,
          hratio       = this.shape_defs[shape].textheight,
          valign       = this.shape_defs[shape].valign,
          align        = this.shape_defs[shape].align,
          fs,c,t;
      this.n_objects++;
      if( x <= -w/2 || x >= this.WIDTH+w/2 || y <= -h/2 || y >= this.HEIGHT+h/2 ) {
        return 0;
      }
      this.drawn_objects++;
      c = this.draw_shape( { shape: shape, fill_color: fill_color, x: x, y: y, h: h, w: w, r: r,
                             stroke_width: stroke_width, stroke_color: stroke_color, stroke_style: stroke_style, title: ttl } );
      var mf = 12;
      if( 'fit_text' in pars ) {
        if( 'txtpos' in pars && pars.txtpos === 'tr' ) {
          valign = 'top';
          align  = 'right';
        }
        t = this.align_text( {
          x: x,
          y: y,
          t: nm,
          w: w*vratio,
          h: h*hratio,
          max_font: mf,
          opts: { cursor:'pointer','font-weight': 'bold', fill:'#000000', title: ttl  },
          align: align,
          valign: valign,
          pad: 1
        } );
        t.click( function( e ) { self.object_click( this, e ); } );
      } else if( r>12 ) {
        fs = (r<40 ? r:40)/2.7;
        t = this.paper.text( x,y, nm ).attr( {cursor:'pointer','font-size': fs, 'font-weight': 'bold', fill:'#000000', title: ttl  } );
        t.click( function( e ) { self.object_click( this, e ); } );
      } else {
        this.paper.text( x, y+r+6, nm ).attr( {opacity: 0.6,'stroke-width':3,stroke:'#fff','font-size': 10, 'font-weight': 'bold', fill:'#fff' } );
        t = this.paper.text( x, y+r+6, nm ).attr( {'font-size': 10, 'font-weight': 'bold', fill:'#cc0000', title: ttl } );
        t.click( function( e ) { self.object_click( this, e ); } );
      }
      c.click( function( e ) { self.object_click( this, e ); } );
      return c;
    },
    draw_shape: function( pars ) {
      var c, str, st_style;
      switch( pars.shape ) {
        case 'circle':
          c = this.paper.circle( pars.x, pars.y, pars.r );
          break;
        case 'ellipse':
          c = this.paper.ellipse( pars.x, pars.y, pars.w/2, pars.h/2 );
          break;
        case 'rectangle' :
        case 'roundrectangle' :
          c = this.paper.rect( pars.x - pars.w/2, pars.y - pars.h/2, pars.w, pars.h );
          break;
        default:
          str = pars.shape in this.shape_defs ? this.shape_defs[pars.shape].line : pars.shape;
          c = this.paper.path('M' + pars.x+ ' ' + pars.y +
            str.replace(
              /(-?\d+(\.\d+)?)[ ](-?\d+(\.\d+)?)/g,
              function (m,p1,p2,p3) { return (p1 * pars.w)+' '+(p3 * pars.h); }
            ) + 'z' );
      }
      st_style = pars.stroke_style in this.line_styles ? this.line_styles[ pars.stroke_style ] : pars.stroke_style;
      c.attr({cursor:'pointer',fill:pars.fill_color,stroke:pars.stroke_color,'stroke-width':pars.stroke_width,title: pars.title,
        'stroke-dasharray': st_style});
      return c;
    },

    /* jshint -W074 */
    draw_connection: function(x,y,x1,y1,d,pars) {
      var self         = this,
          ttl          = 'title' in pars ? pars.title : '',
          stroke_width = 'stroke_width' in pars && pars.stroke_width ? pars.stroke_width : 1,
          pattern      = 'pattern'      in pars                      ? pars.pattern : '',
          start        = 'start'        in pars                      ? pars.start : '',
          end          = 'end'          in pars                      ? pars.end : '',
          stroke_color = 'color' in pars ? pars.color: '#666',
          d1           = 0,
          t;
      this.n_connections++;
      if( pattern in this.line_styles ) {
        pattern = this.line_styles[ pattern ];
      }
      // The following is nasty... it is to work out which lines to draw...
      if( d ) {
        d1 = 1;
      } else {
        if( x1 > 0 && x1 < this.WIDTH && y1 > 0 && y1 < this.HEIGHT ) {
          d1 = 1;
        }
        if( x > this.WIDTH && x1 < this.WIDTH ) {
          if( x1 < 0 ) { // Does it cross the rhs
            t = y + (this.WIDTH - x1) * (y-y1)/(x-x1);
            if( t > 0 && t < this.HEIGHT ) {
              d1= 1;
            }
            // Or the lhs
            t = y + (0 - x1) * (y-y1)/(x-x1);
            if( t > 0 && t < this.HEIGHT ) {
              d1= 1;
            }
          } else {
            // Does it cross the rhs
            t = y + (this.WIDTH - x1) * (y-y1)/(x-x1);
            if( t > 0 && t < this.HEIGHT ) {
              d1= 1;
            }
          }
        }
        if( x < 0 && x1 > 0 ) {
          if( x1 > this.WIDTH ) {
            // Does it cross the lhs
            t = y + (0 - x1) * (y-y1)/(x-x1);
            if( t > 0 && t < this.HEIGHT ) {
              d1= 1;
            }
            // Or the rhs
            t = y + (this.WIDTH - x1) * (y-y1)/(x-x1);
            if( t > 0 && t < this.HEIGHT ) {
              d1= 1;
            }
          } else {
          // Does it cross the lhs
            t = y + (0 - x1) * (y-y1)/(x-x1);
            if( t > 0 && t < this.HEIGHT ) {
              d1= 1;
            }
          }
        }
        if( y > this.HEIGHT && y1 < this.HEIGHT ) {
          if( y1 < 0 ) {
            // Does it cross the top
            t = x + (this.HEIGHT - y1) * (x-x1)/(y-y1);
            if( t > 0 && t < this.WIDTH ) {
              d1= 1;
            }
            // Or the bot
            t = x + (0 - y1) * (x-x1)/(y-y1);
            if( t > 0 && t < this.WIDTH ) {
              d1= 1;
            }
          } else {
            // Does it cross the top
            t = x + (this.HEIGHT - y1) * (x-x1)/(y-y1);
            if( t > 0 && t < this.WIDTH ) {
              d1= 1;
            }
          }
        }
        if( y < 0 && y1 > 0 ) {
          if( y1 > this.HEIGHT ) {
            // Does it cross the bot
            t = x + (0 - y1) * (x-x1)/(y-y1);
            if( t > 0 && t < this.WIDTH ) {
              d1= 1;
            }
            // Or the top
            t = x + (this.HEIGHT - y1) * (x-x1)/(y-y1);
            if( t > 0 && t < this.WIDTH ) {
              d1= 1;
            }
          } else {
            // Does it cross the bot
            t = x + (0 - y1) * (x-x1)/(y-y1);
            if( t > 0 && t < this.WIDTH ) {
              d1= 1;
            }
          }
        }
      }
      if( d1 ) {
        this.drawn_connections++;
        var jn, jn2;
        if( 'draw_over' in pars ) {
          jn = this.paper.path( 'M'+x+' '+y+'L'+x1+' '+y1 ).attr(
            {cursor:'pointer',stroke:stroke_color,'stroke-width':stroke_width,'title':ttl, 'stroke-dasharray': pattern }
          );
          var l = Math.sqrt( (x1-x)*(x1-x)+(y1-y)*(y1-y) );
          // This makes the line easier to click as it is at least 4px wide!
          jn2 = this.paper.path( 'M'+x+' '+y+'L'+x1+' '+y1 ).attr(
            {cursor:'pointer',stroke:stroke_color,'stroke-opacity':0,'stroke-width':stroke_width+4,'title':ttl}
          );
          if( start in this.arrow_defs ) {
            this.draw_arrow( this.arrow_defs[start], x,y, (x1-x)/l, (y1-y)/l, 3,
              {cursor:'pointer',stroke:stroke_color,'stroke-width':stroke_width} );
          }
          if( end in this.arrow_defs ) {
            this.draw_arrow( this.arrow_defs[end], x1,y1, (x-x1)/l, (y-y1)/l, 3,
            {cursor:'pointer',stroke:stroke_color,'stroke-width':stroke_width} );
          }
        } else {
          jn = this.paper.path( 'M'+x+' '+y+'L'+x1+' '+y1 ).toBack().attr(
            {cursor:'pointer',stroke:stroke_color,'stroke-width':stroke_width,'title':ttl, 'stroke-dasharray': pattern}
          );
          // This makes the line easier to click as it is at least 4px wide!
          jn2 = this.paper.path( 'M'+x+' '+y+'L'+x1+' '+y1 ).toBack().attr(
            {cursor:'pointer',stroke:stroke_color,'stroke-opacity':0,'stroke-width':stroke_width+4,'title':ttl}
          );

        }
        // Some versions of IE draw lines outside the box so we will need to clip them!
        if( this.ie && ( x<0 || x>this.WIDTH || x1 < 0 || x1 > this.WIDTH || y<0 || y>this.HEIGHT || y1<0 || y1>this.HEIGHT) ) {
          jn.attr({'clip-rect':this.clip_rect});
          jn2.attr({'clip-rect':this.clip_rect});
        }
        /* We need to pass the event (e) into the line_click function
        ** so we can get the location of the click */
        jn.click(  function( e ) { self.line_click( this, e ); } );
        jn2.click( function( e ) { self.line_click( this, e ); } );
      }
    },
    /* jshint -W074 */

    /* Support functions */
    get_event_loc: function ( e ) {
      // Get the location of the click relative to the chart
      var posx;
      var posy;
      if (e.pageX || e.pageY) {
        posx = e.pageX;
        posy = e.pageY;
      } else {
        posx = e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft;
        posy = e.clientY + document.body.scrollTop  + document.documentElement.scrollTop;
      }
      return { x: posx - this.jq_obj.offset().left, y: posy - this.jq_obj.offset().top };
    },
    parameter_change: function() {
      var i;
      for(i in this.params) {
        if( this.params[i] !== this.prev_params[i] ) {
          return 1;
        }
      }
      return 0;
    },
    scale_x: function(x) {
      return this.WIDTH/2  + this.SF * this.sc * (x-this.c_x);
    },
    scale_y: function(y) {
      return this.HEIGHT/2  + this.SF * this.sc * (y-this.c_y);
    },
    scale_l: function(x) {
      return this.SF * this.sc * x;
    },
    /* Zoom to box */
    zoom_to_box: function( min_x, min_y, max_x, max_y ) {
      this.c_x = (min_x+max_x)/2;
      this.c_y = (min_y+max_y)/2;
      if( min_x === max_x && min_y === max_y ) {
        this.sc = 5;
      } else {
        if( (max_x-min_x)/this.WIDTH > (max_y-min_y)/this.HEIGHT ) {
          this.sc = 0.85 / this.SF / (max_x-min_x) * this.WIDTH;
        } else {
          this.sc = 0.85 / this.SF / (max_y-min_y) * this.HEIGHT;
        }
      }
      return this;
    },
    /* Popup functions */
    init_popup: function() {
      this.pu_offset   = 10;
      this.pu_elements = [];
      return this;
    },
    push_title: function( string, options ) {
      var x_offset = options && 'x'    in options ? options.x    : 2,
          f_size   = options && 'size' in options ? options.size : 14;
      this.pu_elements.push(this.paper.text( x_offset, this.pu_offset, string ).attr( { 'text-anchor': 'start', 'font-size': f_size, 'font-weight': 'bold' } ) );
      this.pu_offset += 2+f_size;
      return this;
    },
    push_2col:  function( k, v, options ) {
      var x_offset = options && 'x'    in options ? options.x    : 58,
          f_size   = options && 'size' in options ? options.size : 10,
          t;
      this.pu_elements.push( this.paper.text( x_offset,   this.pu_offset, k+':' ).attr( { 'text-anchor': 'end', 'font-size': f_size, 'font-weight': 'bold' } ) );
      t = this.paper.text( x_offset+4, this.pu_offset, v ).attr( { 'text-anchor': 'start', 'font-size': f_size } );
      if( options && 'link' in options ) {
        t.attr({'font-weight':'bold', fill: '#009',cursor:'pointer'}).click(function(){
          window.open(options.link,'_blank'); //open a new tab...
          return false;
        });
      }
      this.pu_elements.push( t );
      this.pu_offset += 2+f_size;
      return this;
    },
    push_string: function( string, options ) {
      var x_offset = options && 'x'    in options ? options.x    : 4,
          f_size   = options && 'size' in options ? options.size : 10,
          t;
      t = this.paper.text( x_offset, this.pu_offset, string ).attr( { 'text-anchor': 'start', 'font-size': f_size } );
      if( options && 'link' in options ) {
        t.attr({'font-weight':'bold', fill: '#009',cursor:'pointer'}).click(function(){
          window.open(options.link,'_blank'); //open a new tab...
          return false;
        });
      }
      if( options && 'click' in options ) {
        t.attr({'font-weight':'bold', fill: '#009',cursor:'pointer'}).click(options.click);
      }
      this.pu_elements.push( t );
      this.pu_offset += 2+f_size;
      return this;
    }
  };
}());
