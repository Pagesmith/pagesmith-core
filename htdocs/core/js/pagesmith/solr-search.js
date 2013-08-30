/*global escapeHTML */
/* Define parameters ... */
String.prototype.reverse=function(){return this.split("").reverse().join("");};

PageSmith.SolrSearch = function ( ) {
  this.facet_field  = 'domain';
  this.par = {
    facet:            true,
    'facet.field':    '{!ex=dt}'+this.facet_field,
    'facet.limit':    100,
    'facet.mincount': 1,
    'json.nl':        'map',
    wt:               'json',
    rows:             10,
    q:                '',
    start:            0
  };
  this.xhr          = false;
  this.divs         = '';
  this.facet        = '';
  this.live_host    = '';
  this.n_pad        = 2;
  this.max_page     = 50; // If max page is > 50 then don't include max page links!
  this.n_end        = 2;
  this.search_url   = '';
  this.placeholder  = 'Enter search here...';
  this.tmpls        = {};
  this.aliases      = {};
  this.null_search  = true;
};


/* Now modify the prototype */
PageSmith.SolrSearch.prototype = {
  /* Support methods ... */
  commify: function (X) {
    return (X.toString()).reverse().
           replace(/(\d{3})/g,"$1,").
           reverse().
           replace(/^,/,'');
  },
  label: function( d ) {
    return this.tmpls[d] ? this.tmpls[d].label : d;
  },
  set_facet_field: function ( k ) {
    this.facet_fields = k;
    this.par['facet.field'] = '{!ex=dt}'+k;
  },
  /* Methods to set properties - used by setup script */
  add_template: function( key, template ) {
    this.tmpls[key] = template;
  },
  add_alias: function( key, alias ) {
    this.aliases[alias] = key;
  },
  set_search_url: function( url ) {
    this.search_url = url;
  },

  /* Initialisation function */
  init: function () {
    /** General initialisation of object **/
    var that = this;
    /* Get host information from header of page...
       Used in format DOC to remove domain part of link if this
       is a dev/staging/sandbox copy of a live server - so links
       go back to self rather than live site!
       */
    this.live_host = $("head meta[name='X-site-domain']").attr('content');
    /* Get the message divs... */
    this.divs = $('#search_res').html().replace(/<h2.*?h2>/,'');

    /* Copy value from tr search box into this search box, and store on object */
    $('#search_input').val( $('#q').val() );
    this.par.q = $('#search_input').val();
    /* Add click/submit functionality */
    /* Check to see if value is placeholder and if so clear entry on mouse down/focus
       and v-v for blur  */
    $('#search_input').on('mousedown focus',function(){
      if( $(this).val() === that.placeholder ) {
        $(this).val('');
      }
    }).on('blur',function(){
      if( $(this).val() === '' ) {
        $(this).val(that.placeholder);
      }
    });
    /* Form entry box */
    $('#search_form').submit(function(e){
      e.preventDefault();
      var val = $('#search_input').val();
      if( val === that.placeholder || val === '' ) {
        val = '*:*';
      }
      if( that.par.q !== val ) { // Only if value as changed!
        that.par.q     = val;
        that.par.start = 0;
        that.search();
      }
    });
    /* Pager click links... */
    $('#search_res').on('click','.pager span span',function() {
      that.par.start = (parseInt($(this).html().replace(/,/g,''),10)-1) * that.par.rows;
      that.search();
    });
    /* General de-restrict link */
    $('#search_res').on('click','#search_derestrict',function() {
      that.facet='';
      delete that.par.fq;
      that.search();
    });
    /* Functionality for click links in the right hand side */
    $('#search_counts').on('click','li',function() {
      var z = $(this).metadata();
      if( z.facet === '' && that.facet === '' ) {
        return;
      }
      if( that.facet === z.facet || z.facet === '' ) {
        delete that.par.fq;
        that.facet='';
      } else {
        that.facet = z.facet;
        that.par.fq='{!tag=dt}'+that.facet_field+':"'+ z.facet+'"';
      }
      that.par.start = 0;
      that.search();
    });
  },

/* Generating results methods */
  format_doc: function ( doc, hl ) {
    /** Format of an individual search response... **/
    var facet = doc[this.facet_field],title,defn,url,body_txt,vis_url;
    if( this.aliases[facet] ) {
      facet = this.aliases[facet];
    }
    if( this.tmpls[facet] ) {
      defn  = this.tmpls[facet];
      title = $.map( defn.title, function(k) { return hl[k]?hl[k]:(doc[k]?doc[k]:k); } ).join('');
      url   = $.map( defn.link,  function(k) { return doc[k]?doc[k]:k; } ).join('');
      if( ! url.match(/^https?:\/\//) ) {
        url   = 'http://'+url;
      }/*jsl:ignore*/
      body_txt = '<dl class="twocol">'+$.map(defn.fields,function(v,k) { return '<dt>'+v+'</dt><dd>'+(hl[k]?hl[k][0]:escapeHTML(doc[k]))+'</dd>'; } ).join('')+'</dl>';
      /*jsl:end*/
      facet = defn.label;
    } else {
      /*jsl:ignore*/
      url       = escapeHTML(doc.domain_url);
      /*jsl:end*/
      title     = hl.name ? hl.name : doc.name;
      if( typeof(title) === 'undefined' ) {
        title = 'No title';
      }
      body_txt  = hl.text ? hl.text.join() : '';
    }
    vis_url = url;

    if( url.indexOf('http://'+this.live_host+'/') === 0) {
      url = url.replace('http://'+this.live_host+'/','/');
    }
    if( url.indexOf('https://'+this.live_host+'/') === 0) {
      url = url.replace('https://'+this.live_host+'/','/');
    }
    body_txt.replace(/<\/?strong>/g,'');
    return '<h4><span>'+facet+'</span><a href="'+url+'">'+title+'</a></h4><p><a href="'+url+'">'+vis_url+'</a></p><p>'+body_txt+'</p>';
  },

  paginate: function( no_docs ) {
    /* Generate pagination links at the top of the page */
    if( no_docs === 1 ) {
      return '<p class="pager">Your search returned one result</p>';
    }
    var first_res    = this.par.start+1,
        last_res     = this.par.start+this.par.rows < no_docs ? this.par.start+this.par.rows : no_docs,
        total_pages  = Math.ceil(no_docs/this.par.rows),
        page         = Math.floor(this.par.start/this.par.rows),
        pn           = 0,
        html         = '<p class="pager">Your search returned '+this.commify(no_docs)+' results';
    if( total_pages > 1 ) {
      html +=', showing '+
          this.commify( first_res )+( first_res === last_res ? '' : '-'+this.commify( last_res ))+
          ':  <span>';
      while (pn < total_pages) {
        if( pn < this.n_end || pn >= total_pages - this.n_end || (pn > page - this.n_pad - 1 && pn < page + this.n_pad + 1) ) {
          html += pn === page ? '<strong>' + this.commify(pn + 1) + '</strong>' : '<span>' + this.commify(pn + 1) + '</span>';
          pn++;
        } else {
          html += '...';
          if( pn >= page && total_pages > this.max_page ) {
            break;
          }
          pn = pn < page ? page - this.n_pad : total_pages - this.n_end;
        }
      }
      html += '</span>';
    }
    return html+'</p>';
  },

  render_results: function ( data ) {
    /** Render results and counts returned by solr **/

    // Hide waiting notice...
    $('#search_waiting').hide();

    /* Create main header block */
    /*jsl:ignore*/
    var that=this, header = '<h2>Search results for <em>'+escapeHTML(data.responseHeader.params.q==='*:*'?'*':data.responseHeader.params.q)+'</em>';
    /*jsl:end*/
    if( this.facet ) {
      header += ' in <strong>'+this.label(this.facet)+'</strong>';
    }
    header += '</h2>';

    /* Update search counts panel if there are any entries */
    var facet_values = data.facet_counts.facet_fields[this.facet_field], tp = 0, html, li_class, tooltip;
    html = $.map( facet_values, function(count,f) {
      li_class = that.facet ? (that.facet === f ? 'search_active ' : 'search_inactive ' ) : '';
      tooltip  = that.facet === f ? 'remove restriction' : 'restrict to this category';
      tp+=count;
      return '<li class="'+li_class +'{facet:'+"'"+f+"'"+'}" title="'+tooltip+'"><span>'+that.commify(count)+'</span>'+that.label(f)+'</li>';
    }).join('');
    if( tp ) {
      html += '<li class="search_total {facet:'+"''"+'}" title="Show all results"><span>'+this.commify(tp)+'</span>All results</li>';
        $('#search_counts'   ).show();
        $('#search_counts ul').html( html );
    } else {
      $('#search_counts'   ).hide();
    }

    /* Update the main panel */
    if( data.response.numFound === 0 ) {
      // No results :(
      $('#search_res').html(header+'<p class="pager">Your search returned no results</p>'+
        this.divs+
        (this.facet && tp>0 ? '<p id="search_derestrict">Remove restriction to <strong>'+ this.label(this.facet)+'</strong></p>' : '') );
    } else {
      // Results - include pagination links, warning panels & rendered documents...
      $('#search_res'   ).html(
        header + this.paginate( data.response.numFound ) +
        this.divs +
        $.map( data.response.docs, function(doc){
          return that.format_doc( doc, data.highlighting[doc.uid] );
        } ).join('') );
    }
  },

/* Handle an individual search */
  search: function () {
    /** Main search functionality - abort any outstanding requests, put up spinner and send request to solr **/
    var that = this;
    // Hide search failed message
    $('#search_failed').hide();
    // Convert null input into search everything: "*:*" query string...
    if( this.par.q === this.placeholder || this.par.q === '' ) {
      this.par.q = '*:*';
    }
    // Do nothing if the search string is empty and null_search is false!
    if( ! this.null_search && this.par.q === '*:*' ) {
      $('#search_counts').hide();
      return;
    }
    // Abort any active requests
    if( this.xhr ) {
      this.xhr.abort();
      this.xhr = false;
    }
    // Show spinner and caption...!
    /*jsl:ignore*/
    $('#search_waiting span').html( 'for <em>'+escapeHTML(this.par.q)+'</em>'+
    /*jsl:end*/
      (this.facet ? ' in <strong>'+this.label(this.facet)+'</strong>' : '') );
    $('#search_waiting').show();
    // Send off request....
    this.xhr = $.ajax({
      dataType: 'json',
      url: this.search_url + '?'+$.map( this.par, function(v,k) { return k+'='+encodeURIComponent(v); } ).join('&'),
      error: function( xh, st ) {
        $('#search_waiting').hide();
        if( st !== 'abort' ) {
          $('#search_failed').show();
        }
      },
      success: function( data ) {
        that.xhr = false;
        that.render_results( data );
      }
    });
  }
};
