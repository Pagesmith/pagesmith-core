/*jsl:ignoreall*/
"object"!==typeof JSON2&&(JSON2={});(function(){function c(c){return 10>c?"0"+c:c}function D(c){d.lastIndex=0;return d.test(c)?'"'+c.replace(d,function(c){var g=O[c];return"string"===typeof g?g:"\\u"+("0000"+c.charCodeAt(0).toString(16)).slice(-4)})+'"':'"'+c+'"'}function l(d,M){var g,r,p,H,I=j,q,i=M[d];i&&"object"===typeof i&&(g=i,p=Object.prototype.toString.apply(g),i="[object Date]"===p?isFinite(g.valueOf())?g.getUTCFullYear()+"-"+c(g.getUTCMonth()+1)+"-"+c(g.getUTCDate())+"T"+c(g.getUTCHours())+":"+c(g.getUTCMinutes())+":"+c(g.getUTCSeconds())+"Z":null:"[object String]"===p||"[object Number]"===p||"[object Boolean]"===p?g.valueOf():"[object Array]"!==p&&"function"===typeof g.toJSON?g.toJSON(d):g);"function"===typeof z&&(i=z.call(M,d,i));switch(typeof i){case "string":return D(i);case "number":return isFinite(i)?""+i:"null";case "boolean":case "null":return""+i;case "object":if(!i)return"null";j+=w;q=[];if("[object Array]"===Object.prototype.toString.apply(i)){H=i.length;for(g=0;g<H;g+=1)q[g]=l(g,i)||"null";p=0===q.length?"[]":j?"[\n"+j+q.join(",\n"+j)+"\n"+I+"]":"["+q.join(",")+"]";j=I;return p}if(z&&"object"===typeof z){H=z.length;for(g=0;g<H;g+=1)"string"===typeof z[g]&&(r=z[g],(p=l(r,i))&&q.push(D(r)+(j?": ":":")+p))}else for(r in i)Object.prototype.hasOwnProperty.call(i,r)&&(p=l(r,i))&&q.push(D(r)+(j?": ":":")+p);p=0===q.length?"{}":j?"{\n"+j+q.join(",\n"+j)+"\n"+I+"}":"{"+q.join(",")+"}";j=I;return p}}var t=RegExp("[\x00\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]","g"),d=RegExp('[\\\\\\"\x00-\u001f\u007f-\u009f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]',"g"),j,w,O={"\u0008":"\\b","\t":"\\t","\n":"\\n","\u000c":"\\f","\r":"\\r",'"':'\\"',"\\":"\\\\"},z;if("function"!==typeof JSON2.stringify)JSON2.stringify=function(c,d,g){var r;w=j="";if("number"===typeof g)for(r=0;r<g;r+=1)w+=" ";else"string"===typeof g&&(w=g);if((z=d)&&"function"!==typeof d&&("object"!==typeof d||"number"!==typeof d.length))throw Error("JSON2.stringify");return l("",{"":c})};if("function"!==typeof JSON2.parse)JSON2.parse=function(c,d){function g(c,j){var l,q,i=c[j];if(i&&"object"===typeof i)for(l in i)Object.prototype.hasOwnProperty.call(i,l)&&(q=g(i,l),void 0!==q?i[l]=q:delete i[l]);return d.call(c,j,i)}var j,c=""+c;t.lastIndex=0;t.test(c)&&(c=c.replace(t,function(c){return"\\u"+("0000"+c.charCodeAt(0).toString(16)).slice(-4)}));if(/^[\],:{}\s]*$/.test(c.replace(RegExp('\\\\(?:["\\\\/bfnrt]|u[0-9a-fA-F]{4})',"g"),"@").replace(RegExp('"[^"\\\\\n\r]*"|true|false|null|-?\\d+(?:\\.\\d*)?(?:[eE][+\\-]?\\d+)?',"g"),"]").replace(RegExp("(?:^|:|,)(?:\\s*\\[)+","g"),"")))return j=eval("("+c+")"),"function"===typeof d?g({"":j},""):j;throw new SyntaxError("JSON2.parse");}})();"object"!==typeof _paq&&(_paq=[]);"object"!==typeof Piwik&&(Piwik=function(){function c(b){return"undefined"!==typeof b}function D(b){return"object"===typeof b}function l(b){return"string"===typeof b||b instanceof String}function t(){var b,c,k;for(b=0;b<arguments.length;b+=1)k=arguments[b],c=k.shift(),l(c)?N[c].apply(N,k):c.apply(N,k)}function d(b,c,k,f){if(b.addEventListener)return b.addEventListener(c,k,f),!0;if(b.attachEvent)return b.attachEvent("on"+c,k);b["on"+c]=k}function j(b,c){var k="",f,d;for(f in P)Object.prototype.hasOwnProperty.call(P,f)&&(d=P[f][b],"function"===typeof d&&(k+=d(c)));return k}function w(){var b;if(!W){W=!0;j("load");for(b=0;b<ka.length;b++)ka[b]()}return!0}function O(b,c){var k=h.createElement("script");k.type="text/javascript";k.src=b;k.readyState?k.onreadystatechange=function(){var b=this.readyState;if("loaded"===b||"complete"===b)k.onreadystatechange=null,c()}:k.onload=c;h.getElementsByTagName("head")[0].appendChild(k)}function z(){var b="";try{b=e.top.document.referrer}catch(c){if(e.parent)try{b=e.parent.document.referrer}catch(k){b=""}}if(""===b)b=h.referrer;return b}function za(b){return(b=/^([a-z]+):/.exec(b))?b[1]:null}function M(b){var c=/^(?:(?:https?|ftp):)\/*(?:[^@]+@)?([^:/#]+)/.exec(b);return c?c[1]:b}function g(b,c){var k=RegExp("[\\?&#]"+c+"=([^&#]*)").exec(b);return k?Aa(k[1]):""}function r(b){var c=function(b,c){return b<<c|b>>>32-c},k=function(b){var c="",d,f;for(d=7;0<=d;d--)f=b>>>4*d&15,c+=f.toString(16);return c},f,d,g=[],j=1732584193,h=4023233417,e=2562383102,i=271733878,l=3285377520,m,s,o,p,y,q=[],b=Ca(x(b));m=b.length;for(f=0;f<m-3;f+=4)d=b.charCodeAt(f)<<24|b.charCodeAt(f+1)<<16|b.charCodeAt(f+2)<<8|b.charCodeAt(f+3),q.push(d);switch(m&3){case 0:f=2147483648;break;case 1:f=b.charCodeAt(m-1)<<24|8388608;break;case 2:f=b.charCodeAt(m-2)<<24|b.charCodeAt(m-1)<<16|32768;break;case 3:f=b.charCodeAt(m-3)<<24|b.charCodeAt(m-2)<<16|b.charCodeAt(m-1)<<8|128}for(q.push(f);14!==(q.length&15);)q.push(0);q.push(m>>>29);q.push(m<<3&4294967295);for(b=0;b<q.length;b+=16){for(f=0;16>f;f++)g[f]=q[b+f];for(f=16;79>=f;f++)g[f]=c(g[f-3]^g[f-8]^g[f-14]^g[f-16],1);d=j;m=h;s=e;o=i;p=l;for(f=0;19>=f;f++)y=c(d,5)+(m&s|~m&o)+p+g[f]+1518500249&4294967295,p=o,o=s,s=c(m,30),m=d,d=y;for(f=20;39>=f;f++)y=c(d,5)+(m^s^o)+p+g[f]+1859775393&4294967295,p=o,o=s,s=c(m,30),m=d,d=y;for(f=40;59>=f;f++)y=c(d,5)+(m&s|m&o|s&o)+p+g[f]+2400959708&4294967295,p=o,o=s,s=c(m,30),m=d,d=y;for(f=60;79>=f;f++)y=c(d,5)+(m^s^o)+p+g[f]+3395469782&4294967295,p=o,o=s,s=c(m,30),m=d,d=y;j=j+d&4294967295;h=h+m&4294967295;e=e+s&4294967295;i=i+o&4294967295;l=l+p&4294967295}y=k(j)+k(h)+k(e)+k(i)+k(l);return y.toLowerCase()}function p(b,c,d){if("translate.googleusercontent.com"===b)""===d&&(d=c),c=g(c,"u"),b=M(c);else if("cc.bingj.com"===b||"webcache.googleusercontent.com"===b||"74.6."===b.slice(0,5))c=h.links[0].href,b=M(c);return[b,c,d]}function H(b){var c=b.length;"."===b.charAt(--c)&&(b=b.slice(0,c));"*."===b.slice(0,2)&&(b=b.slice(1));return b}function I(b){b=b&&b.text?b.text:b;if(!l(b)){var d=h.getElementsByTagName("title");if(d&&c(d[0]))b=d[0].text}return b}function q(b,c){if(c)return c;"piwik.php"===b.slice(-9)&&(b=b.slice(0,b.length-9));return b}function i(b){var c=/index\.php\?module=Overlay&action=startOverlaySession&idsite=([0-9]+)&period=([^&]+)&date=([^&]+)$/.exec(h.referrer);if(c){if(c[1]!==""+b)return!1;e.name="Piwik_Overlay###"+c[2]+"###"+c[3]}b=e.name.split("###");return 3===b.length&&"Piwik_Overlay"===b[0]}function Za(c,d,g){var f=e.name.split("###"),j=f[1],h=f[2],i=q(c,d);O(i+"plugins/Overlay/client/client.js?v=1",function(){Piwik_Overlay_Client.initialize(i,g,j,h)})}function X(b,q){function k(a,n,c,b,d,f){if(!Q){var g;c&&(g=new Date,g.setTime(g.getTime()+c));h.cookie=a+"="+x(n)+(c?";expires="+g.toGMTString():"")+";path="+(b||"/")+(d?";domain="+d:"")+(f?";secure":"")}}function f(a){return Q?0:(a=RegExp("(^|;)[ ]*"+a+"=([^;]*)").exec(h.cookie))?Aa(a[2]):0}function w(a){var n;return Da?(n=/#.*/,a.replace(n,"")):a}function A(a){var n,c,b;for(n=0;n<ca.length;n++){c=H(ca[n].toLowerCase());if(a===c)return!0;if("."===c.slice(0,1)){if(a===c.slice(1))return!0;b=a.length-c.length;if(0<b&&a.slice(b)===c)return!0}}return!1}function t(a){var n=new Image(1,1);n.onload=function(){};n.src=Y+(0>Y.indexOf("?")?"?":"&")+a}function O(a){try{var n=e.XMLHttpRequest?new e.XMLHttpRequest:e.ActiveXObject?new ActiveXObject("Microsoft.XMLHTTP"):null;n.open("POST",Y,!0);n.onreadystatechange=function(){4===this.readyState&&200!==this.status&&t(a)};n.setRequestHeader("Content-Type","application/x-www-form-urlencoded; charset=UTF-8");n.send(a)}catch(c){t(a)}}function F(a,n){var c=new Date;la||("POST"===Ea?O(a):t(a),ma=c.getTime()+n)}function G(a){return Fa+a+"."+Z+"."+Ga}function N(){if(Q)return"0";if(!c(v.cookieEnabled)){var a=G("testcookie");k(a,"1");return"1"===f(a)?"1":"0"}return v.cookieEnabled?"1":"0"}function m(){Ga=Ha((J||na)+(K||"/")).slice(0,4)}function s(){var a=G("cvar"),a=f(a);return a.length&&(a=JSON2.parse(a),D(a))?a:{}}function o(){oa=(new Date).getTime()}function P(){var a=Math.round((new Date).getTime()/1E3),n=f(G("id"));n?(a=n.split("."),a.unshift("0")):(pa||(pa=Ha((v.userAgent||"")+(v.platform||"")+JSON2.stringify(L)+a).slice(0,16)),a=["1",pa,a,0,a,"",""]);return a}function y(){var a=f(G("ref"));if(a.length)try{if(a=JSON2.parse(a),D(a))return a}catch(n){}return["","",0,""]}function V(){var a=Q;Q=!1;k(G("id"),"",-86400,K,J);k(G("ses"),"",-86400,K,J);k(G("cvar"),"",-86400,K,J);k(G("ref"),"",-86400,K,J);Q=a}function E(a,n,b,d){var e,i=new Date,m=Math.round(i.getTime()/1E3),l,o,p,q,s,u,r,v,t,z,D=B,O=G("ses"),H=G("ref"),N=G("cvar");r=P();z=f(O);var C=y(),I=da||Ia,R,E;Q&&V();if(la)return"";l=r[0];o=r[1];q=r[2];p=r[3];s=r[4];u=r[5];c(r[6])||(r[6]="");r=r[6];c(d)||(d="");var F=h.characterSet||h.charset;if(!F||"utf-8"===F.toLowerCase())F=null;R=C[0];E=C[1];v=C[2];t=C[3];if(!z){p++;u=s;if(!qa||!R.length){for(e in ea)if(Object.prototype.hasOwnProperty.call(ea,e)&&(R=g(I,ea[e]),R.length))break;for(e in fa)if(Object.prototype.hasOwnProperty.call(fa,e)&&(E=g(I,fa[e]),E.length))break}s=M($);z=t.length?M(t):"";if(s.length&&!A(s)&&(!qa||!z.length||A(z)))t=$;if(t.length||R.length)v=m,C=[R,E,v,w(t.slice(0,1024))],k(H,JSON2.stringify(C),Ja,K,J)}a+="&idsite="+Z+"&rec=1&r="+(""+Math.random()).slice(2,8)+"&h="+i.getHours()+"&m="+i.getMinutes()+"&s="+i.getSeconds()+"&url="+x(w(I))+($.length?"&urlref="+x(w($)):"")+"&_id="+o+"&_idts="+q+"&_idvc="+p+"&_idn="+l+(R.length?"&_rcn="+x(R):"")+(E.length?"&_rck="+x(E):"")+"&_refts="+v+"&_viewts="+u+((""+r).length?"&_ects="+r:"")+((""+t).length?"&_ref="+x(w(t.slice(0,1024))):"")+(F?"&cs="+x(F):"");i=JSON2.stringify(T);2<i.length&&(a+="&cvar="+x(i));for(e in L)Object.prototype.hasOwnProperty.call(L,e)&&(a+="&"+e+"="+L[e]);n?a+="&data="+x(JSON2.stringify(n)):S&&(a+="&data="+x(JSON2.stringify(S)));if(B){n=JSON2.stringify(B);2<n.length&&(a+="&_cvar="+x(n));for(e in D)Object.prototype.hasOwnProperty.call(D,e)&&(""===B[e][0]||""===B[e][1])&&delete B[e];k(N,JSON2.stringify(B),ra,K,J)}sa&&ta?a+="&gt_ms="+ta:sa&&U&&U.timing&&U.timing.requestStart&&U.timing.responseEnd&&(a+="&gt_ms="+(U.timing.responseEnd-U.timing.requestStart));e=p;d=c(d)&&(""+d).length?d:r;k(G("id"),o+"."+q+"."+e+"."+m+"."+u+"."+d,Ka,K,J);k(O,"*",ra,K,J);a+=j(b);ua.length&&(a+="&"+ua);return a}function X(a,n,b,d,f,g){var e="idgoal=0",i,j=new Date,k=[],h;(""+a).length&&(e+="&ec_id="+x(a),i=Math.round(j.getTime()/1E3));e+="&revenue="+n;(""+b).length&&(e+="&ec_st="+b);(""+d).length&&(e+="&ec_tx="+d);(""+f).length&&(e+="&ec_sh="+f);(""+g).length&&(e+="&ec_dt="+g);if(u){for(h in u)if(Object.prototype.hasOwnProperty.call(u,h)){c(u[h][1])||(u[h][1]="");c(u[h][2])||(u[h][2]="");if(!c(u[h][3])||0===(""+u[h][3]).length)u[h][3]=0;if(!c(u[h][4])||0===(""+u[h][4]).length)u[h][4]=1;k.push(u[h])}e+="&ec_items="+x(JSON2.stringify(k))}e=E(e,S,"ecommerce",i);F(e,C)}function Ya(a,n){var c=new Date,b=E("action_name="+x(I(a||La)),n,"log");F(b,C);va&&aa&&!Ma&&(Ma=!0,d(h,"click",o),d(h,"mouseup",o),d(h,"mousedown",o),d(h,"mousemove",o),d(h,"mousewheel",o),d(e,"DOMMouseScroll",o),d(e,"scroll",o),d(h,"keypress",o),d(h,"keydown",o),d(h,"keyup",o),d(e,"resize",o),d(e,"focus",o),d(e,"blur",o),oa=c.getTime(),setTimeout(function $a(){var a=new Date;oa+aa>a.getTime()&&(va<a.getTime()&&(a=E("ping=1",n,"ping"),F(a,C)),setTimeout($a,aa))},aa))}function Ba(a,c,b){a=E(c+"="+x(w(a)),b,"link");F(a,C)}function ba(a){var c,b,e=["","webkit","ms","moz"],f;if(!Na)for(b=0;b<e.length;b++)if(f=e[b],Object.prototype.hasOwnProperty.call(h,""!==f?f+"H"+"hidden".slice(1):"hidden")){"prerender"===h[""!==f?f+"V"+"visibilityState".slice(1):"visibilityState"]&&(c=!0);break}c?d(h,f+"visibilitychange",function ab(){h.removeEventListener(f+"visibilitychange",ab,!1);a()}):a()}function wa(a,c){var b,d="(^| )(piwik[_-]"+c;if(a)for(b=0;b<a.length;b++)d+="|"+a[b];return RegExp(d+")( |$)")}function Oa(a){for(var b,d;null!==(b=a.parentNode)&&c(b)&&"A"!==(d=a.tagName.toUpperCase())&&"AREA"!==d;)a=b;if(c(a.href)){b=a.hostname||M(a.href);var e=b.toLowerCase();b=a.href.replace(b,e);if(!/^(javascript|vbscript|jscript|mocha|livescript|ecmascript|mailto):/i.test(b)){a=a.className;d=b;var e=A(e),f=wa(Pa,"download"),g=wa(Qa,"link"),h=RegExp("\\.("+ga+")([?&#]|$)","i");if(a=g.test(a)?"link":f.test(a)||h.test(d)?"download":e?0:"link")b=Ca(b),Ba(b,a)}}}function xa(a){var b,c,a=a||e.event;b=a.which||a.button;c=a.target||a.srcElement;"click"===a.type?c&&Oa(c):"mousedown"===a.type?(1===b||2===b)&&c?(ha=b,ia=c):ha=ia=null:"mouseup"===a.type&&(b===ha&&c===ia&&Oa(c),ha=ia=null)}function Ra(a,b){b?(d(a,"mouseup",xa,!1),d(a,"mousedown",xa,!1)):d(a,"click",xa,!1)}function Sa(a){if(!Ta){Ta=!0;var b,c=wa(Ua,"ignore"),d=h.links;if(d)for(b=0;b<d.length;b++)c.test(d[b].className)||Ra(d[b],a)}}var ja={},ya=p(h.domain,e.location.href,z()),na=H(ya[0]),Ia=ya[1],$=ya[2],Ea="GET",Y=b||"",Va="",ua="",Z=q||"",da,La=h.title,ga="7z|aac|ar[cj]|as[fx]|avi|bin|csv|deb|dmg|docx?|exe|flv|gif|gz|gzip|hqx|jar|jpe?g|js|mp(2|3|4|e?g)|mov(ie)?|ms[ip]|od[bfgpst]|og[gv]|pdf|phps|png|pptx?|qtm?|ra[mr]?|rpm|sea|sit|tar|t?bz2?|tgz|torrent|txt|wav|wm[av]|wpd||xlsx?|xml|z|zip",ca=[na],Ua=[],Pa=[],Qa=[],C=500,va,aa,Da,S,ea=["pk_campaign","piwik_campaign","utm_campaign","utm_source","utm_medium"],fa=["pk_kwd","piwik_kwd","utm_term"],Fa="_pk_",J,K,Q=!1,la,Na,qa,Ka=63072E6,ra=18E5,Ja=15768E6,sa=!0,ta=0,B=!1,T={},u={},L={},Ta=!1,Ma=!1,oa,ha,ia,Ha=r,Ga,pa;(function(){var a,b,d={pdf:"application/pdf",qt:"video/quicktime",realp:"audio/x-pn-realaudio-plugin",wma:"application/x-mplayer2",dir:"application/x-director",fla:"application/x-shockwave-flash",java:"application/x-java-vm",gears:"application/x-googlegears",ag:"application/x-silverlight"},f=/Mac OS X.*Safari\//.test(v.userAgent)?e.devicePixelRatio||1:1;if(!/MSIE/.test(v.userAgent)){if(v.mimeTypes&&v.mimeTypes.length)for(a in d)Object.prototype.hasOwnProperty.call(d,a)&&(b=v.mimeTypes[d[a]],L[a]=b&&b.enabledPlugin?"1":"0");if("unknown"!==typeof navigator.javaEnabled&&c(v.javaEnabled)&&v.javaEnabled())L.java="1";if("function"===typeof e.GearsFactory)L.gears="1";L.cookie=N()}L.res=Wa.width*f+"x"+Wa.height*f})();m();j("run",function(a,b){var d=null;if(l(a)&&!c(ja[a])&&b){if(D(b))d=b;else if(l(b))try{eval("hookObj ="+b)}catch(e){}ja[a]=d}return d});return{hook:ja,getHook:function(a){return ja[a]},getVisitorId:function(){return P()[1]},getVisitorInfo:function(){return P()},getAttributionInfo:function(){return y()},getAttributionCampaignName:function(){return y()[0]},getAttributionCampaignKeyword:function(){return y()[1]},getAttributionReferrerTimestamp:function(){return y()[2]},getAttributionReferrerUrl:function(){return y()[3]},setTrackerUrl:function(a){Y=a},setSiteId:function(a){Z=a},setCustomData:function(a,b){D(a)?S=a:(S||(S=[]),S[a]=b)},appendToTrackingUrl:function(a){ua=a},getCustomData:function(){return S},setCustomVariable:function(a,b,d,e){c(e)||(e="visit");if(0<a)if(b=c(b)&&!l(b)?""+b:b,d=c(d)&&!l(d)?""+d:d,b=[b.slice(0,200),d.slice(0,200)],"visit"===e||2===e)!1===B&&(B=s()),B[a]=b;else if("page"===e||3===e)T[a]=b},getCustomVariable:function(a,b){var d;c(b)||(b="visit");if("page"===b||3===b)d=T[a];else if("visit"===b||2===b)!1===B&&(B=s()),d=B[a];return!c(d)||d&&""===d[0]?!1:d},deleteCustomVariable:function(a,b){this.getCustomVariable(a,b)&&this.setCustomVariable(a,"","",b)},setLinkTrackingTimer:function(a){C=a},setDownloadExtensions:function(a){ga=a},addDownloadExtensions:function(a){ga+="|"+a},setDomains:function(a){ca=l(a)?[a]:a;ca.push(na)},setIgnoreClasses:function(a){Ua=l(a)?[a]:a},setRequestMethod:function(a){Ea=a||"GET"},setReferrerUrl:function(a){$=a},setCustomUrl:function(a){var b=Ia,c;if(za(a))da=a;else if("/"===a.slice(0,1))da=za(b)+"://"+M(b)+a;else{b=w(b);if(0<=(c=b.indexOf("?")))b=b.slice(0,c);if((c=b.lastIndexOf("/"))!==b.length-1)b=b.slice(0,c+1);da=b+a}},setDocumentTitle:function(a){La=a},setAPIUrl:function(a){Va=a},setDownloadClasses:function(a){Pa=l(a)?[a]:a},setLinkClasses:function(a){Qa=l(a)?[a]:a},setCampaignNameKey:function(a){ea=l(a)?[a]:a},setCampaignKeywordKey:function(a){fa=l(a)?[a]:a},discardHashTag:function(a){Da=a},setCookieNamePrefix:function(a){Fa=a;B=s()},setCookieDomain:function(a){J=H(a);m()},setCookiePath:function(a){K=a;m()},setVisitorCookieTimeout:function(a){Ka=1E3*a},setSessionCookieTimeout:function(a){ra=1E3*a},setReferralCookieTimeout:function(a){Ja=1E3*a},setConversionAttributionFirstReferrer:function(a){qa=a},disableCookies:function(){Q=!0;L.cookie="0"},deleteCookies:function(){V()},setDoNotTrack:function(a){var b=v.doNotTrack||v.msDoNotTrack||f("DNT");(la=a&&("yes"===b||"1"===b))&&this.disableCookies()},addListener:function(a,b){Ra(a,b)},enableLinkTracking:function(a){W?Sa(a):ka.push(function(){Sa(a)})},disablePerformanceTracking:function(){sa=!1},setGenerationTimeMs:function(a){ta=parseInt(a,10)},setHeartBeatTimer:function(a,b){va=(new Date).getTime()+1E3*a;aa=1E3*b},killFrame:function(){if(e.location!==e.top.location)e.top.location=e.location},redirectFile:function(a){if("file:"===e.location.protocol)e.location=a},setCountPreRendered:function(a){Na=a},trackGoal:function(a,b,c){ba(function(){var d=E("idgoal="+a+(b?"&revenue="+b:""),c,"goal");F(d,C)})},trackLink:function(a,b,c){ba(function(){Ba(a,b,c)})},trackPageView:function(a,b){i(Z)?ba(function(){Za(Y,Va,Z)}):ba(function(){Ya(a,b)})},trackSiteSearch:function(a,b,d){ba(function(){var e=E("search="+x(a)+(b?"&search_cat="+x(b):"")+(c(d)?"&search_count="+d:""),void 0,"sitesearch");F(e,C)})},setEcommerceView:function(a,b,d,e){!c(d)||!d.length?d="":d instanceof Array&&(d=JSON2.stringify(d));T[5]=["_pkc",d];c(e)&&(""+e).length&&(T[2]=["_pkp",e]);if(c(a)&&a.length||c(b)&&b.length){c(a)&&a.length&&(T[3]=["_pks",a]);if(!c(b)||!b.length)b="";T[4]=["_pkn",b]}},addEcommerceItem:function(a,b,c,d,e){a.length&&(u[a]=[a,b,c,d,e])},trackEcommerceOrder:function(a,b,d,e,f,g){(""+a).length&&c(b)&&X(a,b,d,e,f,g)},trackEcommerceCartUpdate:function(a){c(a)&&X("",a,"","","","")}}}var ma,P={},h=document,v=navigator,Wa=screen,e=window,U=e.performance||e.mozPerformance||e.msPerformance||e.webkitPerformance,W=!1,ka=[],x=e.encodeURIComponent,Aa=e.decodeURIComponent,Ca=unescape,N,A,V;d(e,"beforeunload",function(){var b;j("unload");if(ma){do b=new Date;while(b.getTimeAlias()<ma)}},!1);(function(){var b;h.addEventListener?d(h,"DOMContentLoaded",function k(){h.removeEventListener("DOMContentLoaded",k,!1);w()}):h.attachEvent&&(h.attachEvent("onreadystatechange",function f(){"complete"===h.readyState&&(h.detachEvent("onreadystatechange",f),w())}),h.documentElement.doScroll&&e===e.top&&function Xa(){if(!W){try{h.documentElement.doScroll("left")}catch(b){setTimeout(Xa,0);return}w()}}());/WebKit/.test(v.userAgent)&&(b=setInterval(function(){if(W||/loaded|complete/.test(h.readyState))clearInterval(b),w()},10));d(e,"load",w,!1)})();Date.prototype.getTimeAlias=Date.prototype.getTime;N=new X;for(A=0;A<_paq.length;A++)if("setTrackerUrl"===_paq[A][0]||"setSiteId"===_paq[A][0])t(_paq[A]),delete _paq[A];for(A=0;A<_paq.length;A++)_paq[A]&&t(_paq[A]);_paq=new function(){return{push:t}};V={addPlugin:function(b,c){P[b]=c},getTracker:function(b,c){return new X(b,c)},getAsyncTracker:function(){return N}};"function"===typeof define&&define.amd&&define(["piwik"],[],function(){return V});return V}());"function"!==typeof piwik_log&&(piwik_log=function(c,D,l,t){function d(c){try{return eval("piwik_"+c)}catch(d){}}var j=Piwik.getTracker(l,D);j.setDocumentTitle(c);j.setCustomData(t);(c=d("tracker_pause"))&&j.setLinkTrackingTimer(c);(c=d("download_extensions"))&&j.setDownloadExtensions(c);(c=d("hosts_alias"))&&j.setDomains(c);(c=d("ignore_classes"))&&j.setIgnoreClasses(c);j.trackPageView();d("install_tracker")&&(piwik_track=function(c,d,l,t){j.setSiteId(d);j.setTrackerUrl(l);j.trackLink(c,t)},j.enableLinkTracking())});