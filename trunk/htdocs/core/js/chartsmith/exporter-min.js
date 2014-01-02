'use strict';
/* jsxhint ignore:start */
/*jsl:ignoreall*/
$(function(){if(Raphael.svg){$("body").first().append('<form action="/action/Svg" method="post" id="svgform"><input type="hidden" value="" name="svg" id="svgvalue"/></form>');$(".raphael-export svg").livequery(function(){var b=$(this).parent(),a=b.attr("id");b.after('<div class="raphael-buttons"><a class="export-image svg" title="'+a+'">Download SVG</a> <a title="'+a+'" class="export-image png">Download PNG</a></div>')});$("body").on("click",".export-image",function(){var a=$(this).attr("title"),b=$(this).hasClass("png")?"png":"svg";$("#svgvalue").val($("#"+a).html());$("#svgform").attr({target:"_blank",action:"/action/Svg/"+b+"/"+a}).submit()})}});
/* jsxhint ignore:end */
