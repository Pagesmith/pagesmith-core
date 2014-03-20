(function($){
  'use strict';
  /**
   * Reference links code. Javascript code related to the references
   * panel, expanding collapsing abstracts etc, and code to copy the
   * title of a paper into the title tag of any cited reference.
   * @author:   js5 (James Smith)
   * @version:  $Id$
   * @requires: jQuery, jquery.livequery.js
   * @see:      Component::References, Component::Cite
   */

  /**
   * Attaches an "onclick" event to all "h4" title tags
   * inside "ref-coll" classed elements so that the abstract, authors
   * etc can be shown/hidden
   */

  $('body').on('click','.ref-coll h4',function () {
    $(this).closest('.ref-coll').toggleClass('ref-closed');
  });

  /**
   * On each footnote (generated by the Cite directive) grabs the
   * title of the publication from the References block and uses it
   * as the title tag for the link.
   */

  function get_surname(obj) {
    return obj.html().split(' ')[0];
  }
  $('.ref-coll h4').livequery(function () {
    $(this).attr('title','Click to show/hide abstract...');
  });
  $('.fncite a').livequery(function () {
    var h = $(this).prop('hash'), t, yr, autl, aut, ent, ent_ref, n_auth;
    if (h && $(h).closest('li.periodical').length) {
      ent = $(h).closest('li.periodical');
      ent_ref = h.substr(1).replace('_', ' ');

      $(this).attr('title', ent_ref + ': ' + ent.find('h4').text());
      if ($(this).closest('span').hasClass('refname')) {
        t = ent.find('.year');
        yr = t.length > 0 ? t.first().html() : '-';
        autl = ent.find('.author');
        n_auth = autl.length;
        if( ent.find('.authors em').length ) {
          n_auth+=10;
        }
        switch (n_auth) {
        case 0:
          aut = '-';
          break;
        case 1:
          aut = get_surname(autl.first());
          break;
        case 2:
          aut = get_surname(autl.first()) + ' and ' + get_surname(autl.first().next());
          break;
        default:
          aut = get_surname(autl.first()) + ' <em>et al</em>';
          break;
        }
        $(this).html('<span class="hidden">' + ent_ref + ': </span>' + aut + ', ' + yr);
      }
      $(this).click(function () {
        $($(this).prop('hash')).parents('.tabc').each(function () {
          $('.tabs a[href=#' + $(this).attr('id') + ']').click();
        });
      });
    }
  });
}(jQuery));
