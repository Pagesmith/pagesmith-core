/*globals Chartsmith: true */
(function($){
  'use strict';

  function render_genbank(dom_node_ref) {
    var dom_node = $(dom_node_ref), url = dom_node.attr('title'), dom_node_width = $(dom_node).width();
    dom_node.removeClass('genbank').removeAttr('title');
    $.getJSON(url, {}, function (resp) {
      //var genbank = new Chartsmith.Genbank(dom_node, resp, dom_node_width);
      (new Chartsmith.Genbank(dom_node, resp, dom_node_width))  // Create the object
        .filter_features().process_features()                   // Prep features!
        .place_features().resize_image().render_features();     // These can be used to re-draw the image!
    });
  }

  $('.genbank:visible').livequery(function () { render_genbank(this); });
}());
