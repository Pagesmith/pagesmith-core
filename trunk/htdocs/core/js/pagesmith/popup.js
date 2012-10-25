$.fn.pagesmith_popup = function(e, callback, options) {
  var details = callback( this );
  var el_pos = $(this).offset(),
      el_wid = $(this).outerWidth(),
      el_hei = $(this).outerHeight(),
      x_pos  = e.pageX,
      y_pos  = e.pageY,
      z,
      arrow,
      t     = $('<div>', { 'class': 'info_popup' });

  if( details.title ) {
    t.append( '<h3><span class="close">X</span>' + details.title + '</h3>' + details.body );
  } else {
    t.append( details.body );
  }

  if( options.className ) {
    t.addClass( options.className );
  }
  if( details.id ) {
    $('#'+details.id).remove();
    $('#'+'__ARROW__'+details.id).remove();
    t.attr('id',details.id);
  }
  t.find('.close').click(function(){
    var t = $(this).closest('div');
    t.prev().filter('.info_popup_arrow').remove();
    t.remove();
  });
  $('body').children().first().before( t );

  /* We need to do some clever stuff here if we need to flip sides due to space constraints... */
  if( options.v_rel || options.h_rel ) {
    x_pos = el_pos.left + el_wid * ( (options.h_rel === 'right'  ? 1: 0) + (options.h_rel !== 'left' ? 1: 0) ) /2;
    y_pos = el_pos.top  + el_hei * ( (options.v_rel === 'bottom' ? 1: 0) + (options.v_rel !== 'top'  ? 1: 0) ) /2;
  }
  x_pos -= $(window).outerWidth()/2 - $('body').outerWidth()/2; /* Pagesmith tweak because we use margins to center body.. */
  t.css({top: y_pos+'px',left: x_pos+'px'});
  if( options.showArrow ) {
    z = t.find('h3').outerHeight();
    if( options.showArrow === 'top' || options.showArrow === 'bottom' ) {
      // Need to work out where to draw the arrow relative to the box!
      1;
    } else {
      // We need to move the box...
      // Create the arrow - then clear the appropriate borders!
      arrow = $('<div>', { 'class':'info_popup_arrow' }).append('.').css(
        {'border-width':z,'border-top-width':z/2,'border-bottom-width':z/2,'border-top-color':'transparent','border-bottom-color':'transparent'}
      );
      if( options.showArrow === 'right' ) {
        /* Move arrow... */
        t.css( 'left', (x_pos-z-t.outerWidth())+'px' );
        t.css( 'top',  (y_pos-z/2)+'px' );
        arrow.css({'border-right-color':'transparent',left: x_pos-z+'px',top:(y_pos-z/2)+'px'});
      } else {
        t.css({left:(x_pos+z)+'px',top:(y_pos-z/2)+'px'});
        arrow.css({'border-left-color':'transparent',left:(x_pos-z)+'px',top:(y_pos-z/2)+'px'});
      }
      // And position the arrow...
    }
    if( options.arrow_class ) {
      arrow.addClass( options.arrow_class );
    }
    if( details.id ) {
      arrow.attr('id','__ARROW__' + details.id );
    }
    $('body').children().first().before(arrow);
  }
};
