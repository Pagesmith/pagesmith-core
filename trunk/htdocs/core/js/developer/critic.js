$('#hide-ignore').click(function () {
  $(this).val($(this).val() === 'Show ignored' ? 'Hide ignored' : 'Show ignored');
  $('.ignore').toggleClass('ignore-show');
}).click();

$('#hide-forced').click(function () {
  $(this).val($(this).val() === 'Show forced' ? 'Hide forced' : 'Show forced');
  $('.forced').toggleClass('forced-show');
}).click();

$('#hide-info').click(function () {
  $(this).val($(this).val() === 'Show info' ? 'Hide info' : 'Show info');
  $('.info').toggleClass('info-show');
}).click();

$('.goto').live('click', function () {
  $('a[href=#source]').trigger('click');
  $(document).scrollTop($('#line_' + $(this).text()).position().top);
  return true;
});
$('#hide-ind').click(function () {
  if ($(this).val() === 'Show individual') {
    $('.ind').addClass('ind-show');
    $(this).val('Hide individual');
  } else {
    $('.ind').removeClass('ind-show');
    $(this).val('Show individual');
  }
}).click();

$('.collapse_ol').live('click', function () { $(this).closest('li').find('ol').toggle(); });
$(function () { $('.collapse_ol').click(); });

$('.ind-container').click(function () {$(this).find('ol').toggleClass('ind-show'); });

$('.description').click(function () {$(this).find('div').toggleClass('info-hid'); });

$('#severity').change(function () {
  var v = $(this).val(), i;
  for (i = 5; i; i--) {
    if (i < v) {
      $('.severity-' + i).addClass('severity-hide');
    } else {
      $('.severity-' + i).removeClass('severity-hide');
    }
  }
});

