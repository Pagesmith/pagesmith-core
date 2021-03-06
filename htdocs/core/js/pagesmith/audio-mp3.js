(function($){
  'use strict';
  /* JavaScript module which converts mp3 links into embedded ogg/mp3 players */
  Pagesmith.On.load('.mp3', function(){
    var URL = $(this).attr('href');
    var OGG_URL = URL.replace(/\.mp3$/, '.ogg');
    var audioTagSupport = !!(document.createElement('audio').canPlayType);
    if( audioTagSupport ) {
      $(this).replaceWith( '<audio controls="controls" style="width:300px"><source src="' + OGG_URL + '" type="audio/ogg" /><source src="' + URL + '" type="audio/mpeg" /><'+'/audio>' );
    } else {
      $(this).replaceWith( '<embed src="' + URL + '" width="320" height="20" autostart="true" loop="false"  controller="true"><' + '/embed>' );
    }
  });
}(jQuery));
