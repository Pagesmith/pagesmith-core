/**
 * Simple image based presentation viewer. Takes a The images in a div,
 * and converts them into a simple carousel - with both mouse and
 * keyboard control ..
 * And now with a simple transition
 *
 * @author:   js5 (James Smith)
 * @version:  $Id$
 * @requires: jQuery
 *
 *
 */

(function ($) {

  var settings = $.metadata && $('.carousel').metadata() ? $('.carousel').metadata() : {};

  // Length of time a slide is displayed for:
  var SLIDE_INTERVAL      = settings['slide_interval']      || 900; // 4 seconds
  var DELAY_START         = settings['delay_start']         || 200;
  var TRANSITION_INTERVAL = settings['transition_interval'] || 250; // 1/4 second between slides.
  TRANSITION_INTERVAL *= 1;
  DELAY_START *= 1;
  SLIDE_INTERVAL *= 1;

  var DIMENSION_X =         settings['image_width']         || '320px';
  var DIMENSION_Y =         settings['image_height']        || '200px';

// auto_advance_temporary_pause = Prevent a transition from happening when anyone manually starts anything (click or type)

$.extend($.easing,
  {
   outCubic: function (x, t, b, c, d) {

  var ts=(t/=d)*t;
  var tc=ts*t;
  return b+c*(tc + -3*ts + 3*t);

//  var ts=(t/=d)*t;
//  var tc=ts*t;
//  return b+c*(33*tc*ts + -106*ts*ts + 126*tc + -67*ts + 15*t);  

//        return c*(t/=d)*t + b;
    }

  }
);

  var active = false; // Prevent anything from happening once a transition has started

  var f_preshid = function(){$(this).hide().addClass('preshid');};

  var thin_1     = { width: "0px",       height: DIMENSION_Y };
  var full_left  = { width: DIMENSION_X, height: DIMENSION_Y, left: "0"};
  var thin_right = { width:   "0",       height: DIMENSION_Y, left: DIMENSION_X };
  var thin_left  = { width:   "0",       height: DIMENSION_Y, left: "0"};

  var animate_any = function(a_start, a_final, x_final, x,a,t) {
    if (x[0] === a[0]) {
     // console.log( 'not animating transition from self to self');
      return;
      }
    if ( active ) { 
     // console.log( 'not animating because already animating' );
      return;
    } else { 
      active = true;
    }
    //console.log( active );
    var f_finishsettitle = function() {
      a.closest('.carousel').pres_set_title();
      active = false;
      //console.log( active );
      };
    // console.log( t );
    x.animate( x_final, { 'duration': t, 'complete': f_preshid,        'easing': 'outCubic' } );

    a.css( a_start ).removeClass('preshid').show().animate( a_final, 
      { 'duration': t, 'complete': f_finishsettitle, 'easing': 'outCubic' }
      );

  };

  var animate_next = function(x,a,t) {
    animate_any( thin_right,full_left,thin_left,x,a,t );
  };
  var animate_prev = function(x,a,t) {
    animate_any( thin_left,full_left,thin_right,x,a,t );
  };
  var animate_goto = function(x,a,t) {
    animate_any( thin_right,full_left,thin_left,x,a,t );
  };

  // Thing to do after the time mentioned above:
  var st = function() {
    $('body .carousel div span').eq(0).slide_next();
  };

  // Interval management.
  var queue;
  var push_timer = function( timer ) {
    queue = timer;
    return 1;
  };

  var pause_timer = function() {
    if (queue && typeof queue !== 'undefined') {
      // removing timer
  //    console.log( 'Pausing timer' );

      window.clearInterval( queue );
      queue = null;
      return 1;
      }
    return 0;
  };

  var restart_timer = function () {
  //  console.log( 'restarting timer');
    if (queue && typeof queue !== 'undefined') {
      // console.dir( queue );
      // console.log( 'not restarting as already running');
      return 0;
    }
    var intervalID = window.setInterval( st, SLIDE_INTERVAL );
    return push_timer( intervalID );
  };

  // If a key is pressed and we were about to get a timer event.. Stop timers until animation completes.
  var auto_advance_temporary_pause = function () {

   // console.log( 'Pausing animation while keyboard animation happens' );

    if ( $('.carousel .pause:visible').length ) {

      var success = pause_timer();
     // console.log( 'Pausing timer returned ' + success );

      $(':animated').promise().done(function() {
         // console.log( 'restarting timer');
         restart_timer();
      });
    }
  };

  $.fn.pres_set_title = function () {
    var n = $(this).children('img:visible').prevAll('img').length + 1, 
        t = 'Slide ' + n, 
       tt = $(this).children('img:visible').first().attr('title');
    if (tt) {
      t += ': ' + tt;
    }
// display the 'current slide number' in a different way == 'current tab'
    $(this).find('span.slide').eq(n - 1).addClass('active').siblings().removeClass('active');
    $(this).children('.title').text( t );
    return this;
  };

  $(document.documentElement).keyup(function (event) {
    if (!$('.carousel').length) {
      return;
    }
    var k = event.keyCode;
    switch (k) {
    case 33: // pageup
    case 36: // home
      $('.carousel .slide').first().click();
      break;
    case 34: // pagedown
    case 35: // end
      $('.carousel .slide').last().click();
      break;
    case 37: // left arrow
    case 38: // up arrow
      $('.carousel .prev').click();
      break;
    case 32: // space
    case 39: // right arrow
    case 40: // down arrow
      $('.carousel .next').click();
      break;
    default:
      if (k > 48 && k < 58) { // numbers 1..9
        $('.carousel .slide').eq(k - 49).click();
      }
      break;
    }
  });

  $('.carousel').livequery(function () {
      var html = '<div class="title"></div><div><a href="?this=%s" class="prev" title="Previous">&#9664; Back</a>', c = 0;
      $(this).children('img').first().siblings('img').addClass('preshid');
      $(this).children('img').each(function () {
        c++;
        html += ' <span class="slide">' + c + '</span>';
      });
      html += ' <a href="?this=%s" class="next" title="Next">Next &#9654;</a><br /><span class="pause">||Pause</span><span class="play">&gt;Play</span></div>';
      $(this).append(html).pres_set_title();
    });
  $('body').on('click','.carousel img', function () {
    var t = TRANSITION_INTERVAL;
    var x = $(this);
    var a;
    if ($(this).next('img').length) {
      a = $(this).next('img');
    } else {
      a = $(this).siblings('img').first();
    }
    animate_next(x,a,t);
    auto_advance_temporary_pause();
  });

  $.fn.slide_next = function () {
    var t = TRANSITION_INTERVAL;
    var x = $(this).closest('div').siblings('img:visible');
    var a;
    if (x.next('img').length) {
      a = x.next('img');
    } else {
      a = x.siblings('img').first();
    }
    animate_next(x,a,t);
  };
  $.fn.slide_prev = function () {
    var t = TRANSITION_INTERVAL;
    var x = $(this).closest('div').siblings('img:visible');
    var a;
    if (x.prev('img').length) {
      a = x.prev('img');
    } else {
      a = x.siblings('img').last();
    }
    animate_prev(x,a,t);
  };
  $('body').on('click','.carousel .prev', function ( e ) {
    e.preventDefault();
    $(this).slide_prev();
    auto_advance_temporary_pause();
  });
  $('body').on('click','.carousel .next', function( e ) {
    e.preventDefault();
    $(this).slide_next();
    auto_advance_temporary_pause();
  });
  $('body').on('click','.carousel .slide',function() {
    var t = TRANSITION_INTERVAL;
    var x = $(this).closest('div').siblings('img:visible');
    var a = $(this).closest('div').siblings('img').eq($(this).text() - 1);
    animate_goto(x,a,t);
    auto_advance_temporary_pause();
  });

  // AUTO PROGRESS
  $('body').on('click','.carousel .pause',function() {
    if ( active ) { return; }

    if (pause_timer()) { // NOTE: Calls the function to stop the interval_timer
      $(this).hide(); // from here onwards, activate doesn't happen.
      $('.carousel .play').show();
    }
  });
  $('body').on('click','.carousel .play',function() {
    if ( active ) { return; }

    restart_timer();
    $(this).hide();
    $('.carousel .pause').show();
  });

  // slightly longer delay on the first slide
  var begin = function() {
    var q = function () {
      var intervalID = window.setInterval( st, SLIDE_INTERVAL );
      push_timer(intervalID);
      $('.carousel .pause').show();
      };

    // after a couple of seconds, start the show...
    var r          = window.setTimeout( q, DELAY_START );
    // initial setup: can't play if running. can't pause as not running yet

    $('.carousel .pause').hide();
    $('.carousel .play').hide();
    // experiment with absolute positioning:
    $('.carousel div').width( DIMENSION_X );
    $('.carousel img').addClass('absolute').css('left','0').not(':visible').width( '0px' ).height( DIMENSION_Y );
  };
 
  $(document).ready( begin );
}(jQuery));