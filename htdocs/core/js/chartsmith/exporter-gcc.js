'use strict';
/* jsxhint ignore:start */
/*jsl:ignoreall*/
$(function(){Raphael.svg&&($("body").first().append('<form action="/action/Svg" method="post" id="svgform"><input type="hidden" value="" name="svg" id="svgvalue"/></form>'),$(".raphael-export svg").livequery(function(){var a=$(this).parent(),b=a.attr("id");a.after('<div class="raphael-buttons"><a class="export-image svg" title="'+b+'">Download SVG</a> <a title="'+b+'" class="export-image png">Download PNG</a></div>')}),$("body").on("click",".export-image",function(){var a=$(this).attr("title"),b=$(this).hasClass("png")?"png":"svg";$("#svgvalue").val($("#"+a).html());$("#svgform").attr({target:"_blank",action:"/action/Svg/"+b+"/"+a}).submit()}))});
/* jsxhint ignore:end */
