/* globals Raphael: true */
(function($) {
/* Image exporter code */
  'use strict';
  if( Raphael.svg ) {
    $('body').first().append('<form action="/action/Svg" method="post" id="svgform"><input type="hidden" value="" name="svg" id="svgvalue"/><\/form>');
    Pagesmith.On.load('.raphael-export svg', function() {
      var t = $(this).parent(), i = t.attr('id');
      t.after('<div class="raphael-buttons"><a class="export-image svg" title="' + i + '">Download SVG<\/a> <a title="' + i + '" class="export-image png">Download PNG<\/a><\/div>');
    });
    $('body').on('click','.export-image', function () {
      var i = $(this).attr('title'), format = $(this).hasClass('png') ? 'png' : 'svg';
      $('#svgvalue').val($('#' + i).html());
      $('#svgform').attr({target: '_blank', action: '/action/Svg/' + format + '/' + i}).submit();
    });
  }
}(jQuery));
