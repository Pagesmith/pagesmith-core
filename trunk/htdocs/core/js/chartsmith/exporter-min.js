/*jsl:ignoreall*/(function(a){if(Raphael.svg){a("body").first().append('<form action="/action/Svg" method="post" id="svgform"><input type="hidden" value="" name="svg" id="svgvalue"/></form>');a(".raphael-export svg").livequery(function(){var c=a(this).parent(),b=c.attr("id");c.after('<div class="raphael-buttons"><a class="export-image svg" title="'+b+'">Download SVG</a> <a title="'+b+'" class="export-image png">Download PNG</a></div>')});a(".export-image").live("click",function(){var b=a(this).attr("title"),c=a(this).hasClass("png")?"png":"svg";a("#svgvalue").val(a("#"+b).html());a("#svgform").attr({target:"_blank",action:"/action/Svg/"+c+"/"+b}).submit()})}}(jQuery));