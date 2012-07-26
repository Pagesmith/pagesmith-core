/**
 * Simple image based presentation viewer. Takes a The images in a div,
 * and converts them into a simple presentation - with both mouse and
 * keyboard control ..
 *
 * @author:   js5 (James Smith)
 * @version:  $Id$
 * @requires: jQuery
 * @requires: css file to render presentation!
 */

(function ($) {
  $.fn.pres_set_title = function () {
    var n = $(this).children('img:visible').prevAll('img').length + 1, t = 'Slide ' + n, tt = $(this).children('img:visible').first().attr('title');
    if (tt) {
      t += ': ' + tt;
    }
    $(this).find('span').eq(n).addClass('active').siblings().removeClass('active');
    $(this).children('.title').text(t);
    return this;
  };

  $(document.documentElement).keyup(function (event) {
    if (!$('.presentation').length) {
      return;
    }
    var k = event.keyCode;
    switch (k) {
    case 33: // pageup
    case 36: // home
      $('.presentation .slide').first().click();
      break;
    case 34: // pagedown
    case 35: // end
      $('.presentation .slide').last().click();
      break;
    case 37: // left arrow
    case 38: // up arrow
      $('.presentation .prev').click();
      break;
    case 32: // space
    case 39: // right arrow
    case 40: // down arrow
      $('.presentation .next').click();
      break;
    default:
      if (k > 48 && k < 58) { // numbers 1..9
        $('.presentation .slide').eq(k - 49).click();
      }
      break;
    }
  });

  $('.presentation')
    .livequery(function () {
      var html = '<div class="title"></div><div><span class="prev">&lt;prev</span>', c = 0;
      $(this).children('img').first().siblings().addClass('preshid');
      $(this).children('img').each(function () {
        c++;
        html += ' <span class="slide">' + c + '</span>';
      });
      html += ' <span class="next">next&gt;</span></div>';
      $(this).append(html).pres_set_title();
    })
    .find('img')
    .live('click', function () {
      $(this).addClass('preshid');
      if ($(this).next('img').length) {
        $(this).next('img').removeClass('preshid');
      } else {
        $(this).siblings('img').first().removeClass('preshid');
      }
      $(this).closest('.presentation').pres_set_title();
    })
    .end().find('.prev')
    .live('click', function () {
      var x = $(this).closest('div').siblings('img:visible').addClass('preshid');
      if (x.prev('img').length) {
        x.prev('img').removeClass('preshid');
      } else {
        x.siblings('img').last().removeClass('preshid');
      }
      $(this).closest('.presentation').pres_set_title();
    })
    .end().find('.next')
    .live('click', function () {
      var x = $(this).closest('div').siblings('img:visible').addClass('preshid');
      if (x.next('img').length) {
        x.next('img').removeClass('preshid');
      } else {
        x.siblings('img').first().removeClass('preshid');
      }
      $(this).closest('.presentation').pres_set_title();
    })
    .end().find('.slide')
    .live('click', function () {
      $(this).closest('div').siblings('img:visible').addClass('preshid');
      $(this).closest('div').siblings('img').eq($(this).text() - 1).removeClass('preshid');
      $(this).closest('.presentation').pres_set_title();
    });
}(jQuery));
