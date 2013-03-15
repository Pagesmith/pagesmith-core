/*jsl:ignoreall*/
/*!
 * Piwik - Web Analytics
 *
 * JavaScript tracking client
 *
 * @link http://piwik.org
 * @source https://github.com/piwik/piwik/blob/master/js/piwik.js
 * @license http://www.opensource.org/licenses/bsd-license.php Simplified BSD
 */
if(!this.JSON2){this.JSON2={}}(function(){function d(f){return f<10?"0"+f:f}function l(n,m){var f=Object.prototype.toString.apply(n);if(f==="[object Date]"){return isFinite(n.valueOf())?n.getUTCFullYear()+"-"+d(n.getUTCMonth()+1)+"-"+d(n.getUTCDate())+"T"+d(n.getUTCHours())+":"+d(n.getUTCMinutes())+":"+d(n.getUTCSeconds())+"Z":null}if(f==="[object String]"||f==="[object Number]"||f==="[object Boolean]"){return n.valueOf()}if(f!=="[object Array]"&&typeof n.toJSON==="function"){return n.toJSON(m)}return n}var c=new RegExp("[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]","g"),e='\\\\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]',i=new RegExp("["+e,"g"),j,b,k={"\b":"\\b","\t":"\\t","\n":"\\n","\f":"\\f","\r":"\\r",'"':'\\"',"\\":"\\\\"},h;
function a(f){i.lastIndex=0;return i.test(f)?'"'+f.replace(i,function(m){var n=k[m];return typeof n==="string"?n:"\\u"+("0000"+m.charCodeAt(0).toString(16)).slice(-4)})+'"':'"'+f+'"'}function g(s,p){var n,m,t,f,q=j,o,r=p[s];if(r&&typeof r==="object"){r=l(r,s)}if(typeof h==="function"){r=h.call(p,s,r)}switch(typeof r){case"string":return a(r);case"number":return isFinite(r)?String(r):"null";case"boolean":case"null":return String(r);case"object":if(!r){return"null"}j+=b;o=[];if(Object.prototype.toString.apply(r)==="[object Array]"){f=r.length;for(n=0;n<f;n+=1){o[n]=g(n,r)||"null"}t=o.length===0?"[]":j?"[\n"+j+o.join(",\n"+j)+"\n"+q+"]":"["+o.join(",")+"]";j=q;return t}if(h&&typeof h==="object"){f=h.length;for(n=0;n<f;n+=1){if(typeof h[n]==="string"){m=h[n];t=g(m,r);if(t){o.push(a(m)+(j?": ":":")+t)}}}}else{for(m in r){if(Object.prototype.hasOwnProperty.call(r,m)){t=g(m,r);if(t){o.push(a(m)+(j?": ":":")+t)}}}}t=o.length===0?"{}":j?"{\n"+j+o.join(",\n"+j)+"\n"+q+"}":"{"+o.join(",")+"}";j=q;
return t}}if(typeof JSON2.stringify!=="function"){JSON2.stringify=function(o,m,n){var f;j="";b="";if(typeof n==="number"){for(f=0;f<n;f+=1){b+=" "}}else{if(typeof n==="string"){b=n}}h=m;if(m&&typeof m!=="function"&&(typeof m!=="object"||typeof m.length!=="number")){throw new Error("JSON.stringify")}return g("",{"":o})}}if(typeof JSON2.parse!=="function"){JSON2.parse=function(o,f){var n;function m(s,r){var q,p,t=s[r];if(t&&typeof t==="object"){for(q in t){if(Object.prototype.hasOwnProperty.call(t,q)){p=m(t,q);if(p!==undefined){t[q]=p}else{delete t[q]}}}}return f.call(s,r,t)}o=String(o);c.lastIndex=0;if(c.test(o)){o=o.replace(c,function(p){return"\\u"+("0000"+p.charCodeAt(0).toString(16)).slice(-4)})}if((new RegExp("^[\\],:{}\\s]*$")).test(o.replace(new RegExp('\\\\(?:["\\\\/bfnrt]|u[0-9a-fA-F]{4})',"g"),"@").replace(new RegExp('"[^"\\\\\n\r]*"|true|false|null|-?\\d+(?:\\.\\d*)?(?:[eE][+\\-]?\\d+)?',"g"),"]").replace(new RegExp("(?:^|:|,)(?:\\s*\\[)+","g"),""))){n=eval("("+o+")");
return typeof f==="function"?m({"":n},""):n}throw new SyntaxError("JSON.parse")}}}());var _paq=_paq||[],Piwik=Piwik||(function(){var f,a={},o=document,c=navigator,A=screen,x=window,l=false,v=[],h=x.encodeURIComponent,w=x.decodeURIComponent,d=unescape,B,E;function q(M){var i=typeof M;return i!=="undefined"}function m(i){return typeof i==="function"}function z(i){return typeof i==="object"}function j(i){return typeof i==="string"||i instanceof String}function H(){var M,O,N;for(M=0;M<arguments.length;M+=1){N=arguments[M];O=N.shift();if(j(O)){B[O].apply(B,N)}else{O.apply(B,N)}}}function K(O,N,M,i){if(O.addEventListener){O.addEventListener(N,M,i);return true}if(O.attachEvent){return O.attachEvent("on"+N,M)}O["on"+N]=M}function F(N,Q){var M="",P,O;for(P in a){if(Object.prototype.hasOwnProperty.call(a,P)){O=a[P][N];if(m(O)){M+=O(Q)}}}return M}function I(){var i;F("unload");if(f){do{i=new Date()}while(i.getTimeAlias()<f)}}function G(){var M;if(!l){l=true;F("load");for(M=0;M<v.length;M++){v[M]()
}}return true}function k(){var M;if(o.addEventListener){K(o,"DOMContentLoaded",function i(){o.removeEventListener("DOMContentLoaded",i,false);G()})}else{if(o.attachEvent){o.attachEvent("onreadystatechange",function i(){if(o.readyState==="complete"){o.detachEvent("onreadystatechange",i);G()}});if(o.documentElement.doScroll&&x===x.top){(function i(){if(!l){try{o.documentElement.doScroll("left")}catch(N){setTimeout(i,0);return}G()}}())}}}if((new RegExp("WebKit")).test(c.userAgent)){M=setInterval(function(){if(l||/loaded|complete/.test(o.readyState)){clearInterval(M);G()}},10)}K(x,"load",G,false)}function e(N,M){var i=o.createElement("script");i.type="text/javascript";i.src=N;if(i.readyState){i.onreadystatechange=function(){var O=this.readyState;if(O==="loaded"||O==="complete"){i.onreadystatechange=null;M()}}}else{i.onload=M}o.getElementsByTagName("head")[0].appendChild(i)}function r(){var i="";try{i=x.top.document.referrer}catch(N){if(x.parent){try{i=x.parent.document.referrer}catch(M){i=""
}}}if(i===""){i=o.referrer}return i}function g(i){var N=new RegExp("^([a-z]+):"),M=N.exec(i);return M?M[1]:null}function b(i){var N=new RegExp("^(?:(?:https?|ftp):)/*(?:[^@]+@)?([^:/#]+)"),M=N.exec(i);return M?M[1]:i}function y(N,M){var Q=new RegExp("^(?:https?|ftp)(?::/*(?:[^?]+)[?])([^#]+)"),P=Q.exec(N),O=new RegExp("(?:^|&)"+M+"=([^&]*)"),i=P?O.exec(P[1]):0;return i?w(i[1]):""}function n(i){return d(h(i))}function J(ac){var O=function(W,i){return(W<<i)|(W>>>(32-i))},ad=function(aj){var ai="",ah,W;for(ah=7;ah>=0;ah--){W=(aj>>>(ah*4))&15;ai+=W.toString(16)}return ai},R,af,ae,N=[],V=1732584193,T=4023233417,S=2562383102,Q=271733878,P=3285377520,ab,aa,Z,Y,X,ag,M,U=[];ac=n(ac);M=ac.length;for(af=0;af<M-3;af+=4){ae=ac.charCodeAt(af)<<24|ac.charCodeAt(af+1)<<16|ac.charCodeAt(af+2)<<8|ac.charCodeAt(af+3);U.push(ae)}switch(M&3){case 0:af=2147483648;break;case 1:af=ac.charCodeAt(M-1)<<24|8388608;break;case 2:af=ac.charCodeAt(M-2)<<24|ac.charCodeAt(M-1)<<16|32768;break;case 3:af=ac.charCodeAt(M-3)<<24|ac.charCodeAt(M-2)<<16|ac.charCodeAt(M-1)<<8|128;
break}U.push(af);while((U.length&15)!==14){U.push(0)}U.push(M>>>29);U.push((M<<3)&4294967295);for(R=0;R<U.length;R+=16){for(af=0;af<16;af++){N[af]=U[R+af]}for(af=16;af<=79;af++){N[af]=O(N[af-3]^N[af-8]^N[af-14]^N[af-16],1)}ab=V;aa=T;Z=S;Y=Q;X=P;for(af=0;af<=19;af++){ag=(O(ab,5)+((aa&Z)|(~aa&Y))+X+N[af]+1518500249)&4294967295;X=Y;Y=Z;Z=O(aa,30);aa=ab;ab=ag}for(af=20;af<=39;af++){ag=(O(ab,5)+(aa^Z^Y)+X+N[af]+1859775393)&4294967295;X=Y;Y=Z;Z=O(aa,30);aa=ab;ab=ag}for(af=40;af<=59;af++){ag=(O(ab,5)+((aa&Z)|(aa&Y)|(Z&Y))+X+N[af]+2400959708)&4294967295;X=Y;Y=Z;Z=O(aa,30);aa=ab;ab=ag}for(af=60;af<=79;af++){ag=(O(ab,5)+(aa^Z^Y)+X+N[af]+3395469782)&4294967295;X=Y;Y=Z;Z=O(aa,30);aa=ab;ab=ag}V=(V+ab)&4294967295;T=(T+aa)&4294967295;S=(S+Z)&4294967295;Q=(Q+Y)&4294967295;P=(P+X)&4294967295}ag=ad(V)+ad(T)+ad(S)+ad(Q)+ad(P);return ag.toLowerCase()}function D(N,i,M){if(N==="translate.googleusercontent.com"){if(M===""){M=i}i=y(i,"u");N=b(i)}else{if(N==="cc.bingj.com"||N==="webcache.googleusercontent.com"||N.slice(0,5)==="74.6."){i=o.links[0].href;
N=b(i)}}return[N,i,M]}function s(M){var i=M.length;if(M.charAt(--i)==="."){M=M.slice(0,i)}if(M.slice(0,2)==="*."){M=M.slice(1)}return M}function L(M){if(!j(M)){M=M.text||"";var i=o.getElementsByTagName("title");if(i&&q(i[0])){M=i[0].text}}return M}function t(P,T){var V="Piwik_Overlay",S=o.referrer,i=P;if(i.slice(-9)==="piwik.php"){i=i.slice(0,i.length-9)}i.slice(i.slice(0,7)==="http://"?7:8,i.length);S.slice(S.slice(0,7)==="http://"?7:8,S.length);if(S.slice(0,i.length)===i){var N=new RegExp("^"+i+"index\\.php\\?module=Overlay&action=startOverlaySession&idsite=([0-9]+)&period=([^&]+)&date=([^&]+)$");var O=N.exec(S);if(O){var Q=O[1];if(Q!==String(T)){return false}var R=O[2],M=O[3];x.name=V+"###"+R+"###"+M}}var U=x.name.split("###");return U.length===3&&U[0]===V}function C(N,O){var Q=x.name.split("###"),P=Q[1],M=Q[2],i=N;if(i.slice(-9)==="piwik.php"){i=i.slice(0,i.length-9)}e(i+"plugins/Overlay/client/client.js?v=1",function(){Piwik_Overlay_Client.initialize(i,O,P,M)})}function u(af,aE){var P=D(o.domain,x.location.href,r()),aX=s(P[0]),bb=P[1],aK=P[2],aI="GET",O=af||"",a1=aE||"",av,al=o.title,an="7z|aac|ar[cj]|as[fx]|avi|bin|csv|deb|dmg|docx?|exe|flv|gif|gz|gzip|hqx|jar|jpe?g|js|mp(2|3|4|e?g)|mov(ie)?|ms[ip]|od[bfgpst]|og[gv]|pdf|phps|png|pptx?|qtm?|ra[mr]?|rpm|sea|sit|tar|t?bz2?|tgz|torrent|txt|wav|wm[av]|wpd||xlsx?|xml|z|zip",aG=[aX],S=[],az=[],ae=[],aF=500,T,ag,U,V,ap=["pk_campaign","piwik_campaign","utm_campaign","utm_source","utm_medium"],ak=["pk_kwd","piwik_kwd","utm_term"],a9="_pk_",Y,ba,W=false,a4,ar,au,ac=63072000000,ad=1800000,aw=15768000000,R=false,aA={},a5=200,aQ={},a2={},aN=false,aL=false,aJ,aB,Z,ao=J,aM,at;
function aS(bk,bh,bg,bj,bf,bi){if(W){return}var be;if(bg){be=new Date();be.setTime(be.getTime()+bg)}o.cookie=bk+"="+h(bh)+(bg?";expires="+be.toGMTString():"")+";path="+(bj||"/")+(bf?";domain="+bf:"")+(bi?";secure":"")}function ab(bg){if(W){return 0}var be=new RegExp("(^|;)[ ]*"+bg+"=([^;]*)"),bf=be.exec(o.cookie);return bf?w(bf[2]):0}function a6(be){var bf;if(U){bf=new RegExp("#.*");return be.replace(bf,"")}return be}function aW(bg,be){var bh=g(be),bf;if(bh){return be}if(be.slice(0,1)==="/"){return g(bg)+"://"+b(bg)+be}bg=a6(bg);if((bf=bg.indexOf("?"))>=0){bg=bg.slice(0,bf)}if((bf=bg.lastIndexOf("/"))!==bg.length-1){bg=bg.slice(0,bf+1)}return bg+be}function aH(bh){var bf,be,bg;for(bf=0;bf<aG.length;bf++){be=s(aG[bf].toLowerCase());if(bh===be){return true}if(be.slice(0,1)==="."){if(bh===be.slice(1)){return true}bg=bh.length-be.length;if((bg>0)&&(bh.slice(bg)===be)){return true}}}return false}function bd(be){var bf=new Image(1,1);bf.onload=function(){};bf.src=O+(O.indexOf("?")<0?"?":"&")+be
}function aT(be){try{var bg=x.XMLHttpRequest?new x.XMLHttpRequest():x.ActiveXObject?new ActiveXObject("Microsoft.XMLHTTP"):null;bg.open("POST",O,true);bg.onreadystatechange=function(){if(this.readyState===4&&this.status!==200){bd(be)}};bg.setRequestHeader("Content-Type","application/x-www-form-urlencoded; charset=UTF-8");bg.send(be)}catch(bf){bd(be)}}function aq(bg,bf){var be=new Date();if(!a4){if(aI==="POST"){aT(bg)}else{bd(bg)}f=be.getTime()+bf}}function aR(be){return a9+be+"."+a1+"."+aM}function Q(){if(W){return"0"}if(!q(c.cookieEnabled)){var be=aR("testcookie");aS(be,"1");return ab(be)==="1"?"1":"0"}return c.cookieEnabled?"1":"0"}function aC(){aM=ao((Y||aX)+(ba||"/")).slice(0,4)}function aa(){var bf=aR("cvar"),be=ab(bf);if(be.length){be=JSON2.parse(be);if(z(be)){return be}}return{}}function N(){if(R===false){R=aa()}}function a0(){var be=new Date();aJ=be.getTime()}function X(bi,bf,be,bh,bg,bj){aS(aR("id"),bi+"."+bf+"."+be+"."+bh+"."+bg+"."+bj,ac,ba,Y)}function M(){var bf=new Date(),be=Math.round(bf.getTime()/1000),bh=ab(aR("id")),bg;
if(bh){bg=bh.split(".");bg.unshift("0")}else{if(!at){at=ao((c.userAgent||"")+(c.platform||"")+JSON2.stringify(a2)+be).slice(0,16)}bg=["1",at,be,0,be,"",""]}return bg}function i(){var be=ab(aR("ref"));if(be.length){try{be=JSON2.parse(be);if(z(be)){return be}}catch(bf){}}return["","",0,""]}function am(bg,bF,bG,bi){var bD,bf=new Date(),bo=Math.round(bf.getTime()/1000),bI,bE,bk,bw,bA,bn,by,bl,bC,bj=1024,bJ,br,bz=R,bu=aR("id"),bp=aR("ses"),bq=aR("ref"),bK=aR("cvar"),bx=M(),bt=ab(bp),bB=i(),bH=av||bb,bm,be;if(W){W=false;aS(bu,"",-86400,ba,Y);aS(bp,"",-86400,ba,Y);aS(bK,"",-86400,ba,Y);aS(bq,"",-86400,ba,Y);W=true}if(a4){return""}bI=bx[0];bE=bx[1];bw=bx[2];bk=bx[3];bA=bx[4];bn=bx[5];if(!q(bx[6])){bx[6]=""}by=bx[6];if(!q(bi)){bi=""}var bs=o.characterSet||o.charset;if(!bs||bs.toLowerCase()==="utf-8"){bs=null}bm=bB[0];be=bB[1];bl=bB[2];bC=bB[3];if(!bt){bk++;bn=bA;if(!au||!bm.length){for(bD in ap){if(Object.prototype.hasOwnProperty.call(ap,bD)){bm=y(bH,ap[bD]);if(bm.length){break}}}for(bD in ak){if(Object.prototype.hasOwnProperty.call(ak,bD)){be=y(bH,ak[bD]);
if(be.length){break}}}}bJ=b(aK);br=bC.length?b(bC):"";if(bJ.length&&!aH(bJ)&&(!au||!br.length||aH(br))){bC=aK}if(bC.length||bm.length){bl=bo;bB=[bm,be,bl,a6(bC.slice(0,bj))];aS(bq,JSON2.stringify(bB),aw,ba,Y)}}bg+="&idsite="+a1+"&rec=1&r="+String(Math.random()).slice(2,8)+"&h="+bf.getHours()+"&m="+bf.getMinutes()+"&s="+bf.getSeconds()+"&url="+h(a6(bH))+(aK.length?"&urlref="+h(a6(aK)):"")+"&_id="+bE+"&_idts="+bw+"&_idvc="+bk+"&_idn="+bI+(bm.length?"&_rcn="+h(bm):"")+(be.length?"&_rck="+h(be):"")+"&_refts="+bl+"&_viewts="+bn+(String(by).length?"&_ects="+by:"")+(String(bC).length?"&_ref="+h(a6(bC.slice(0,bj))):"")+(bs?"&cs="+h(bs):"");var bh=JSON2.stringify(aA);if(bh.length>2){bg+="&cvar="+h(bh)}for(bD in a2){if(Object.prototype.hasOwnProperty.call(a2,bD)){bg+="&"+bD+"="+a2[bD]}}if(bF){bg+="&data="+h(JSON2.stringify(bF))}else{if(V){bg+="&data="+h(JSON2.stringify(V))}}if(R){var bv=JSON2.stringify(R);if(bv.length>2){bg+="&_cvar="+h(bv)}for(bD in bz){if(Object.prototype.hasOwnProperty.call(bz,bD)){if(R[bD][0]===""||R[bD][1]===""){delete R[bD]
}}}aS(bK,JSON2.stringify(R),ad,ba,Y)}X(bE,bw,bk,bo,bn,q(bi)&&String(bi).length?bi:by);aS(bp,"*",ad,ba,Y);bg+=F(bG);return bg}function aV(bh,bg,bl,bi,be,bo){var bj="idgoal=0",bk,bf=new Date(),bm=[],bn;if(String(bh).length){bj+="&ec_id="+h(bh);bk=Math.round(bf.getTime()/1000)}bj+="&revenue="+bg;if(String(bl).length){bj+="&ec_st="+bl}if(String(bi).length){bj+="&ec_tx="+bi}if(String(be).length){bj+="&ec_sh="+be}if(String(bo).length){bj+="&ec_dt="+bo}if(aQ){for(bn in aQ){if(Object.prototype.hasOwnProperty.call(aQ,bn)){if(!q(aQ[bn][1])){aQ[bn][1]=""}if(!q(aQ[bn][2])){aQ[bn][2]=""}if(!q(aQ[bn][3])||String(aQ[bn][3]).length===0){aQ[bn][3]=0}if(!q(aQ[bn][4])||String(aQ[bn][4]).length===0){aQ[bn][4]=1}bm.push(aQ[bn])}}bj+="&ec_items="+h(JSON2.stringify(bm))}bj=am(bj,V,"ecommerce",bk);aq(bj,aF)}function aU(be,bi,bh,bg,bf,bj){if(String(be).length&&q(bi)){aV(be,bi,bh,bg,bf,bj)}}function a8(be){if(q(be)){aV("",be,"","","","")}}function ay(bh,bi){var be=new Date(),bg=am("action_name="+h(L(bh||al)),bi,"log");
aq(bg,aF);if(T&&ag&&!aL){aL=true;K(o,"click",a0);K(o,"mouseup",a0);K(o,"mousedown",a0);K(o,"mousemove",a0);K(o,"mousewheel",a0);K(x,"DOMMouseScroll",a0);K(x,"scroll",a0);K(o,"keypress",a0);K(o,"keydown",a0);K(o,"keyup",a0);K(x,"resize",a0);K(x,"focus",a0);K(x,"blur",a0);aJ=be.getTime();setTimeout(function bf(){var bj=new Date(),bk;if((aJ+ag)>bj.getTime()){if(T<bj.getTime()){bk=am("ping=1",bi,"ping");aq(bk,aF)}setTimeout(bf,ag)}},ag)}}function aj(be,bh,bf,bi){var bg=am("search="+h(be)+(bh?"&search_cat="+h(bh):"")+(q(bf)?"&search_count="+bf:""),bi,"sitesearch");aq(bg,aF)}function aD(be,bh,bg){var bf=am("idgoal="+be+(bh?"&revenue="+bh:""),bg,"goal");aq(bf,aF)}function aZ(bf,be,bh){var bg=am(be+"="+h(a6(bf)),bh,"link");aq(bg,aF)}function a3(bf,be){if(bf!==""){return bf+be.charAt(0).toUpperCase()+be.slice(1)}return be}function ai(bj){var bi,be,bh=["","webkit","ms","moz"],bg;if(!ar){for(be=0;be<bh.length;be++){bg=bh[be];if(Object.prototype.hasOwnProperty.call(o,a3(bg,"hidden"))){if(o[a3(bg,"visibilityState")]==="prerender"){bi=true
}break}}}if(bi){K(o,bg+"visibilitychange",function bf(){o.removeEventListener(bg+"visibilitychange",bf,false);bj()});return}bj()}function ah(bg,bf){var bh,be="(^| )(piwik[_-]"+bf;if(bg){for(bh=0;bh<bg.length;bh++){be+="|"+bg[bh]}}be+=")( |$)";return new RegExp(be)}function aY(bh,be,bi){var bg=ah(az,"download"),bf=ah(ae,"link"),bj=new RegExp("\\.("+an+")([?&#]|$)","i");return bf.test(bh)?"link":(bg.test(bh)||bj.test(be)?"download":(bi?0:"link"))}function aP(bj){var bh,bf,be;while((bh=bj.parentNode)!==null&&q(bh)&&((bf=bj.tagName.toUpperCase())!=="A"&&bf!=="AREA")){bj=bh}if(q(bj.href)){var bk=bj.hostname||b(bj.href),bl=bk.toLowerCase(),bg=bj.href.replace(bk,bl),bi=new RegExp("^(javascript|vbscript|jscript|mocha|livescript|ecmascript|mailto):","i");if(!bi.test(bg)){be=aY(bj.className,bg,aH(bl));if(be){bg=d(bg);aZ(bg,be)}}}}function bc(be){var bf,bg;be=be||x.event;bf=be.which||be.button;bg=be.target||be.srcElement;if(be.type==="click"){if(bg){aP(bg)}}else{if(be.type==="mousedown"){if((bf===1||bf===2)&&bg){aB=bf;
Z=bg}else{aB=Z=null}}else{if(be.type==="mouseup"){if(bf===aB&&bg===Z){aP(bg)}aB=Z=null}}}}function aO(bf,be){if(be){K(bf,"mouseup",bc,false);K(bf,"mousedown",bc,false)}else{K(bf,"click",bc,false)}}function ax(bf){if(!aN){aN=true;var bg,be=ah(S,"ignore"),bh=o.links;if(bh){for(bg=0;bg<bh.length;bg++){if(!be.test(bh[bg].className)){aO(bh[bg],bf)}}}}}function a7(){var bf,bg,bh={pdf:"application/pdf",qt:"video/quicktime",realp:"audio/x-pn-realaudio-plugin",wma:"application/x-mplayer2",dir:"application/x-director",fla:"application/x-shockwave-flash",java:"application/x-java-vm",gears:"application/x-googlegears",ag:"application/x-silverlight"},be=(new RegExp("Mac OS X.*Safari/")).test(c.userAgent)?x.devicePixelRatio||1:1;if(!((new RegExp("MSIE")).test(c.userAgent))){if(c.mimeTypes&&c.mimeTypes.length){for(bf in bh){if(Object.prototype.hasOwnProperty.call(bh,bf)){bg=c.mimeTypes[bh[bf]];a2[bf]=(bg&&bg.enabledPlugin)?"1":"0"}}}if(typeof navigator.javaEnabled!=="unknown"&&q(c.javaEnabled)&&c.javaEnabled()){a2.java="1"
}if(m(x.GearsFactory)){a2.gears="1"}a2.cookie=Q()}a2.res=A.width*be+"x"+A.height*be}a7();aC();return{getVisitorId:function(){return(M())[1]},getVisitorInfo:function(){return M()},getAttributionInfo:function(){return i()},getAttributionCampaignName:function(){return i()[0]},getAttributionCampaignKeyword:function(){return i()[1]},getAttributionReferrerTimestamp:function(){return i()[2]},getAttributionReferrerUrl:function(){return i()[3]},setTrackerUrl:function(be){O=be},setSiteId:function(be){a1=be},setCustomData:function(be,bf){if(z(be)){V=be}else{if(!V){V=[]}V[be]=bf}},getCustomData:function(){return V},setCustomVariable:function(bf,be,bi,bg){var bh;if(!q(bg)){bg="visit"}if(bf>0){be=q(be)&&!j(be)?String(be):be;bi=q(bi)&&!j(bi)?String(bi):bi;bh=[be.slice(0,a5),bi.slice(0,a5)];if(bg==="visit"||bg===2){N();R[bf]=bh}else{if(bg==="page"||bg===3){aA[bf]=bh}}}},getCustomVariable:function(bf,bg){var be;if(!q(bg)){bg="visit"}if(bg==="page"||bg===3){be=aA[bf]}else{if(bg==="visit"||bg===2){N();be=R[bf]
}}if(!q(be)||(be&&be[0]==="")){return false}return be},deleteCustomVariable:function(be,bf){if(this.getCustomVariable(be,bf)){this.setCustomVariable(be,"","",bf)}},setLinkTrackingTimer:function(be){aF=be},setDownloadExtensions:function(be){an=be},addDownloadExtensions:function(be){an+="|"+be},setDomains:function(be){aG=j(be)?[be]:be;aG.push(aX)},setIgnoreClasses:function(be){S=j(be)?[be]:be},setRequestMethod:function(be){aI=be||"GET"},setReferrerUrl:function(be){aK=be},setCustomUrl:function(be){av=aW(bb,be)},setDocumentTitle:function(be){al=be},setDownloadClasses:function(be){az=j(be)?[be]:be},setLinkClasses:function(be){ae=j(be)?[be]:be},setCampaignNameKey:function(be){ap=j(be)?[be]:be},setCampaignKeywordKey:function(be){ak=j(be)?[be]:be},discardHashTag:function(be){U=be},setCookieNamePrefix:function(be){a9=be;R=aa()},setCookieDomain:function(be){Y=s(be);aC()},setCookiePath:function(be){ba=be;aC()},setVisitorCookieTimeout:function(be){ac=be*1000},setSessionCookieTimeout:function(be){ad=be*1000
},setReferralCookieTimeout:function(be){aw=be*1000},setConversionAttributionFirstReferrer:function(be){au=be},disableCookies:function(){W=true;a2.cookie="0"},setDoNotTrack:function(bf){var be=c.doNotTrack||c.msDoNotTrack;a4=bf&&(be==="yes"||be==="1");if(a4){this.disableCookies()}},addListener:function(bf,be){aO(bf,be)},enableLinkTracking:function(be){if(l){ax(be)}else{v.push(function(){ax(be)})}},setHeartBeatTimer:function(bg,bf){var be=new Date();T=be.getTime()+bg*1000;ag=bf*1000},killFrame:function(){if(x.location!==x.top.location){x.top.location=x.location}},redirectFile:function(be){if(x.location.protocol==="file:"){x.location=be}},setCountPreRendered:function(be){ar=be},trackGoal:function(be,bg,bf){ai(function(){aD(be,bg,bf)})},trackLink:function(bf,be,bg){ai(function(){aZ(bf,be,bg)})},trackPageView:function(be,bf){if(t(O,a1)){ai(function(){C(O,a1)})}else{ai(function(){ay(be,bf)})}},trackSiteSearch:function(be,bg,bf){ai(function(){aj(be,bg,bf)})},setEcommerceView:function(bh,be,bg,bf){if(!q(bg)||!bg.length){bg=""
}else{if(bg instanceof Array){bg=JSON2.stringify(bg)}}aA[5]=["_pkc",bg];if(q(bf)&&String(bf).length){aA[2]=["_pkp",bf]}if((!q(bh)||!bh.length)&&(!q(be)||!be.length)){return}if(q(bh)&&bh.length){aA[3]=["_pks",bh]}if(!q(be)||!be.length){be=""}aA[4]=["_pkn",be]},addEcommerceItem:function(bi,be,bg,bf,bh){if(bi.length){aQ[bi]=[bi,be,bg,bf,bh]}},trackEcommerceOrder:function(be,bi,bh,bg,bf,bj){aU(be,bi,bh,bg,bf,bj)},trackEcommerceCartUpdate:function(be){a8(be)}}}function p(){return{push:H}}K(x,"beforeunload",I,false);k();Date.prototype.getTimeAlias=Date.prototype.getTime;B=new u();for(E=0;E<_paq.length;E++){if(_paq[E][0]==="setTrackerUrl"||_paq[E][0]==="setSiteId"){H(_paq[E]);delete _paq[E]}}for(E=0;E<_paq.length;E++){if(_paq[E]){H(_paq[E])}}_paq=new p();return{addPlugin:function(i,M){a[i]=M},getTracker:function(i,M){return new u(i,M)},getAsyncTracker:function(){return B}}}()),piwik_track,piwik_log=function(b,f,d,g){function a(h){try{return eval("piwik_"+h)}catch(i){}return}var c,e=Piwik.getTracker(d,f);
e.setDocumentTitle(b);e.setCustomData(g);c=a("tracker_pause");if(c){e.setLinkTrackingTimer(c)}c=a("download_extensions");if(c){e.setDownloadExtensions(c)}c=a("hosts_alias");if(c){e.setDomains(c)}c=a("ignore_classes");if(c){e.setIgnoreClasses(c)}e.trackPageView();if(a("install_tracker")){piwik_track=function(i,k,j,h){e.setSiteId(k);e.setTrackerUrl(j);e.trackLink(i,h)};e.enableLinkTracking()}};
