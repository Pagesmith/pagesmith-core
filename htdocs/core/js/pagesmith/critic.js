(function($){
  'use strict';
  $('#hide-ignore').on('click',function () {
    $(this).val($(this).val() === 'Show ignored' ? 'Hide ignored' : 'Show ignored');
    $('.ignore').toggleClass('ignore-show');
  }).trigger('click');

  $('#hide-forced').on('click',function () {
    $(this).val($(this).val() === 'Show forced' ? 'Hide forced' : 'Show forced');
    $('.forced').toggleClass('forced-show');
  }).trigger('click');

  $('#hide-info').on('click',function () {
    $(this).val($(this).val() === 'Show info' ? 'Hide info' : 'Show info');
    $('.info').toggleClass('info-show');
  }).trigger('click');

  $('body').on('click','.goto', function () {
    $('a[href=#source]').trigger('click');
    $(document).scrollTop($('#line_' + $(this).text()).position().top);
    return true;
  });
  $('#hide-ind').on('click',function () {
    if ($(this).val() === 'Show individual') {
      $('.ind').addClass('ind-show');
      $(this).val('Hide individual');
    } else {
      $('.ind').removeClass('ind-show');
      $(this).val('Show individual');
    }
  }).trigger('click');

  $('body').on('click','.collapse_ol', function () { $(this).closest('li').find('ol').toggle(); });
  $(function () { $('.collapse_ol').trigger('click'); });

  $('.ind-container').on('click',function () {$(this).find('ol').toggleClass('ind-show'); });

  $('.description').on('click',function () {$(this).find('div').toggleClass('info-hid'); });

  $('#severity').on('change',function () {
    var v = $(this).val(), i;
    for (i = 5; i; i--) {
      if (i < v) {
        $('.severity-' + i).addClass('severity-hide');
      } else {
        $('.severity-' + i).removeClass('severity-hide');
      }
    }
  });
}(jQuery));
