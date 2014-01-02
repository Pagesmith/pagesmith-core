/* exported wrapped_tb_show */
/* exported tb_show */
/* exported tb_remove */
/* exported replace_tb_show */

/* LEAVE ALONE! */

/*@
 * Copyright (c) 2007 cody lindley
 * Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php
 * @author: Cody Lindley (http://www.codylindley.com)
 * @version: $Id$
*/

/* jshint -W098 */
/* jshint -W074 */
/* jshint -W117 */
/* jshint -W116 */
function tb_getPageSize(){
  'use strict';
  var de = document.documentElement;
  var w = window.innerWidth || (de&&de.clientWidth) || document.body.clientWidth;
  var h = window.innerHeight || (de&&de.clientHeight) || document.body.clientHeight;
  return [w,h];
}

function tb_detectMacXFF() {
  'use strict';
  var userAgent = navigator.userAgent.toLowerCase();
  if (userAgent.indexOf('mac') != -1 && userAgent.indexOf('firefox')!=-1) {
    return true;
  }
}

function tb_remove( ) {
  'use strict';
  $('#TB_imageOff').unbind('click');
  $('#TB_closeWindowButton').unbind('click');
  $('#TB_window').fadeOut('fast',function(){$('#TB_window,#TB_overlay,#TB_HideSelect').trigger('unload').unbind().remove();});
  $('#TB_load').remove();
  if (typeof document.body.style.maxHeight == 'undefined') {//if IE 6
    $('body','html').css({height: 'auto', width: 'auto'});
    $('html').css('overflow','');
  }
  document.onkeydown = '';
  document.onkeyup = '';
  return false;
}

function tb_position( TB_TOP, TB_WIDTH, TB_HEIGHT ) {
  'use strict';
  $('#TB_window').css({marginLeft: '-' + parseInt((TB_WIDTH / 2),10) + 'px', width: TB_WIDTH + 'px'});
  if( !document.all || window.XMLHttpRequest) { // take away ie6
    $('#TB_window').css({marginTop: '-' + (TB_TOP + parseInt((TB_HEIGHT / 2),10) ) + 'px'});
  }
}

function tb_parseQuery ( query ) {
  'use strict';
  var Params = {};
  if ( ! query ) {
    return Params;
  }// return empty object
  var Pairs = query.split(/[;&]/);
  for ( var i = 0; i < Pairs.length; i++ ) {
    var KeyVal = Pairs[i].split('=');
    if ( ! KeyVal || KeyVal.length != 2 ) {
      continue;
    }
    var key = decodeURIComponent( KeyVal[0] );
    var val = decodeURIComponent( KeyVal[1] );
    val = val.replace(/\+/g, ' ');
    Params[key] = val;
  }
  return Params;
}

function tb_show(caption, url, imageGroup) {//function called when the user clicks on a thickbox link
  'use strict';
  var tb_pathToImage = '/core/gfx/anim/loadinganimationround.gif';
  var TB_PrevCaption, TB_PrevURL, TB_PrevHTML,
      TB_NextCaption, TB_NextURL, TB_NextHTML,
      TB_imageCount,  TB_FoundURL, TB_TempArray,
      TB_Counter, imgPreloader, TB_TOP, TB_WIDTH, TB_HEIGHT, ajaxContentW, ajaxContentH;
  try {
    if (typeof document.body.style.maxHeight === 'undefined') {//if IE 6
      $('body','html').css({height: '100%', width: '100%'});
      $('html').css('overflow','hidden');
      if (document.getElementById('TB_HideSelect') === null) {//iframe to hide select elements in ie6
        $('body').append('<iframe id="TB_HideSelect"></iframe><div id="TB_overlay"></div><div id="TB_window"></div>');
        $('#TB_overlay').click(tb_remove);
      }
    }else{//all others
      if(document.getElementById('TB_overlay') === null){
        $('body').append('<div id="TB_overlay"></div><div id="TB_window"></div>');
        $('#TB_overlay').click(tb_remove);
      }
    }

    if(tb_detectMacXFF()){
      $('#TB_overlay').addClass('TB_overlayMacFFBGHack');//use png overlay so hide flash
    }else{
      $('#TB_overlay').addClass('TB_overlayBG');//use background and opacity
    }
    if(caption===null){
      caption='';
    }
    $('body').append('<div id="TB_load"><img src="'+tb_pathToImage+'" /></div>');//add loader to the page
    $('#TB_load').show();//show loader

    var baseURL = url.indexOf('?')!==-1 ? url.substr(0, url.indexOf('?')) : url;

    var urlString = /\.jpg$|\.jpeg$|\.png$|\.gif$|\.bmp$/;
    var urlType = baseURL.toLowerCase().match(urlString);
    var params = {};
    if(urlType == '.jpg' || urlType == '.jpeg' || urlType == '.png' || urlType == '.gif' || urlType == '.bmp'){//code to show images
      TB_PrevCaption = '';
      TB_PrevURL = '';
      TB_PrevHTML = '';
      TB_NextCaption = '';
      TB_NextURL = '';
      TB_NextHTML = '';
      TB_imageCount = '';
      TB_FoundURL = false;
      if(imageGroup){
        TB_TempArray = $('a[rel='+imageGroup+']').get();
        //TB_TempArray = $('a[@rel='+imageGroup+']').get();
        for (TB_Counter = 0; ((TB_Counter < TB_TempArray.length) && (TB_NextHTML === '')); TB_Counter++) {
          //var urlTypeTemp = TB_TempArray[TB_Counter].href.toLowerCase().match(urlString);
          if( TB_TempArray[TB_Counter].href == url ) {
            TB_FoundURL = true;
            TB_imageCount = 'Image ' + (TB_Counter + 1) +' of '+ (TB_TempArray.length);
          } else {
            if (TB_FoundURL) {
              TB_NextCaption = TB_TempArray[TB_Counter].title;
              TB_NextURL = TB_TempArray[TB_Counter].href;
              TB_NextHTML = '<span id="TB_next">&nbsp;&nbsp;<a class="no-img" href="#">Next &gt;</a></span>';
            } else {
              TB_PrevCaption = TB_TempArray[TB_Counter].title;
              TB_PrevURL = TB_TempArray[TB_Counter].href;
              TB_PrevHTML = '<span id="TB_prev">&nbsp;&nbsp;<a class="no-img" href="#">&lt; Prev</a></span>';
            }
          }
        }
      }

      imgPreloader = new Image();
      imgPreloader.onerror = tb_remove;
      imgPreloader.onload = function() {
        imgPreloader.onload = null;

        // Resizing large images - orginal by Christian Montoya edited by me.
        var pagesize = tb_getPageSize();
        var x = pagesize[0] - 150;
        var y = pagesize[1] - 200;
        var imageWidth = imgPreloader.width;
        var imageHeight = imgPreloader.height;
        if (imageWidth > x) {
          imageHeight = imageHeight * (x / imageWidth);
          imageWidth = x;
          if (imageHeight > y) {
            imageWidth = imageWidth * (y / imageHeight);
            imageHeight = y;
          }
        } else if (imageHeight > y) {
          imageWidth = imageWidth * (y / imageHeight);
          imageHeight = y;
          if (imageWidth > x) {
            imageHeight = imageHeight * (x / imageWidth);
            imageWidth = x;
          }
        }
      // End Resizing

        TB_TOP    = 40;
        TB_WIDTH  = imageWidth + 30;
        if( TB_WIDTH < 300 ) {
          TB_WIDTH = 480;
        }
        TB_HEIGHT = imageHeight + 60;
        if( TB_HEIGHT < 300 ) {
          TB_HEIGHT = 300;
        }
        $('#TB_window').append('<a href="" class="no-img" id="TB_ImageOff" title="Close"><img id="TB_Image" src="'+url+
          '" width="'+imageWidth+'" height="'+imageHeight+'" alt="'+caption+'"/></a>' + '<div id="TB_caption">'+caption+
          '<div id="TB_secondLine">' + TB_imageCount + TB_PrevHTML + TB_NextHTML +
          '</div></div><div id="TB_closeWindow"><a href="#" class="no-img" id="TB_closeWindowButton" title="Close">close</a> or Esc Key</div>');

        $('#TB_closeWindowButton').click(tb_remove);

        if( TB_PrevHTML !== '' ) {
          $('#TB_prev').on('click',function( e ){
            e.preventDefault();
            $('#TB_window').remove();
            $('body').append('<div id="TB_window"></div>');
            tb_show(TB_PrevCaption, TB_PrevURL, imageGroup);
            return false;
          });
        }

        if( TB_NextHTML !== '') {
          $('#TB_next').click(function( e ){
            e.preventDefault();
            $('#TB_window').remove();
            $('body').append('<div id="TB_window"></div>');
            tb_show(TB_NextCaption, TB_NextURL, imageGroup);
            return false;
          });
        }

        document.onkeydown = function(e){
          var keycode;
          if (e == null) { // ie
            keycode = event.keyCode;
          } else { // mozilla
            keycode = e.which;
          }
          if(keycode == 27){ // close
            tb_remove();
          } else if(keycode == 190){ // display previous image
            if(TB_NextHTML != '' ){
              document.onkeydown = '';
              goNext();
            }
          } else if(keycode == 188){ // display next image
            if(TB_PrevHTML != ''){
              document.onkeydown = '';
              goPrev();
            }
          }
        };

        tb_position( TB_TOP, TB_WIDTH, TB_HEIGHT );
        $('#TB_load').remove();
        $('#TB_ImageOff').click(tb_remove);
        $('#TB_window').css({display:'block'}); //for safari using css instead of show
      };
      imgPreloader.src = url;
    } else {//code to show html

      var queryString = url.replace(/^[^\?]+\??/,'');
      params = tb_parseQuery( queryString );

      TB_WIDTH  = (params.width*1)  + 30 || $(window).width()  - 40; //defaults to 630 if no paramaters were added to URL
      TB_TOP    = 0;
      TB_HEIGHT = (params.height*1) + 40 || $(window).height() - 40; //defaults to 440 if no paramaters were added to URL
      ajaxContentW = TB_WIDTH - 30;
      ajaxContentH = TB_HEIGHT - 45;

      if(url.indexOf('TB_iframe') != -1){// either iframe or ajax window
        var urlNoQuery = url.split('TB_');
        $('#TB_iframeContent').remove();
        if(params.modal != 'true'){//iframe no modal
          $('#TB_window').append('<div id="TB_title"><div id="TB_ajaxWindowTitle">'+caption+
            '</div><div id="TB_closeAjaxWindow"><a href="#" class="no-img" id="TB_closeWindowButton" title="Close">close</a>'+
            ' or Esc Key</div></div><iframe frameborder="0" hspace="0" src="'+urlNoQuery[0]+
            '" id="TB_iframeContent" name="TB_iframeContent'+Math.round(Math.random()*1000)+
            '" onload="tb_showIframe()" style="width:'+(ajaxContentW + 29)+'px;height:'+(ajaxContentH + 17)+'px;" > </iframe>');
        } else {//iframe modal
          $('#TB_overlay').unbind();
          $('#TB_window').append('<iframe frameborder="0" hspace="0" src="'+urlNoQuery[0]+'" id="TB_iframeContent" name="TB_iframeContent'+
            Math.round(Math.random()*1000)+'" onload="tb_showIframe()" style="width:'+(ajaxContentW + 29)+'px;height:'+(ajaxContentH + 17)+
            'px;"> </iframe>');
        }
      } else {// not an iframe, ajax
        if($('#TB_window').css('display') != 'block'){
          if(params.modal != 'true'){//ajax no modal
            $('#TB_window').append('<div id="TB_title"><div id="TB_ajaxWindowTitle">'+caption+
              '</div><div id="TB_closeAjaxWindow"><a href="#" class="no-img" id="TB_closeWindowButton">close</a>'+
              ' or Esc Key</div></div><div id="TB_ajaxContent" style="width:'+ajaxContentW+'px;height:'+ajaxContentH+'px"></div>');
          }else{//ajax modal
            $('#TB_overlay').unbind();
            $('#TB_window').append('<div id="TB_ajaxContent" class="TB_modal" style="width:'+ajaxContentW+'px;height:'+ajaxContentH+'px;"></div>');
          }
        } else {//this means the window is already up, we are just loading new content via ajax
          $('#TB_ajaxContent')[0].style.width = ajaxContentW +'px';
          $('#TB_ajaxContent')[0].style.height = ajaxContentH +'px';
          $('#TB_ajaxContent')[0].scrollTop = 0;
          $('#TB_ajaxWindowTitle').html(caption);
        }
      }

      $('#TB_closeWindowButton').click(tb_remove);
      if(url.indexOf('TB_inline') != -1){
        $('#TB_ajaxContent').append($('#' + params.inlineId).children());
        $('#TB_window').unload(function () {
          $('#' + params.inlineId).append( $('#TB_ajaxContent').children() ); // move elements back when you're finished
        });
        tb_position( TB_TOP, TB_WIDTH, TB_HEIGHT );
        $('#TB_load').remove();
        $('#TB_window').css({display:'block'});
      }else if(url.indexOf('TB_iframe') != -1){
        tb_position( TB_TOP, TB_WIDTH, TB_HEIGHT );
        if( Object.prototype.toString.call(window.HTMLElement).indexOf('Constructor') > 0 ) { //safari needs help because it will not fire iframe onload
          $('#TB_load').remove();
          $('#TB_window').css({display:'block'});
        }
      } else {
        $('#TB_ajaxContent').load(url += (url.match(/\?/)?'&':'?')+'random=' + (new Date().getTime()),function(){//to do a post change this load method
          tb_position( TB_TOP, TB_WIDTH, TB_HEIGHT );
          $('#TB_load').remove();
          $('#TB_ajaxContent a.thickbox').click(function(event){
            event.preventDefault();
            var t = this.title || this.name || null;
            var a = this.href  || this.alt;
            var g = this.rel   || false;
            tb_show(t,a,g);
            this.blur();
          });
          $('#TB_window').css({display:'block'});
        });
      }
    }
    if(params && !params.modal){
      document.onkeyup = function(e){
        var keycode;
        if (e == null) { // ie
          keycode = event.keyCode;
        } else { // mozilla
          keycode = e.which;
        }
        if(keycode == 27){ // close
          tb_remove();
        }
      };
    }
  } catch(e) {
    //console.log( e );
    //nothing here
  }
}

//helper functions below
function replace_tb_show( url ) {
  'use strict';
  $('#TB_window').unload( function() {
    window.setTimeout( function() {
      tb_show('',url,false);
      $('#TB_window').unload( function() {
        window.setTimeout( function() {
          tb_show(window.saved_title,window.saved_url,false);
        }, 0 ); // minimum delay!
      } );
    }, 0 );     // minimum delay!
  });
  tb_remove();
}

function tb_showIframe(){
  'use strict';
  $('#TB_load').remove();
  $('#TB_window').css({display:'block'});
}

(function($){
  'use strict';
  $('body').on('click','a.thickbox, area.thickbox, input.thickbox',function(){
    var t = this.title || this.name || null;
    var a = this.href  || this.alt;
    var g = this.rel   || false;
    tb_show(t,a,g);
    this.blur();
    return false;
  });
}(jQuery));

function wrapped_tb_show(caption,url,params) {
  'use strict';
  window.saved_title = caption;
  window.saved_url   = url;
  tb_show(caption,url,params);
}

/* jshint +W116 */
/* jshint +W117 */
/* jshint +W074 */
/* jshint +W098 */

