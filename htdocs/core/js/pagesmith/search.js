/*----------------------------------------------------------------------
  Search box code

  author: js5 (James Smith)
  svn-id: $Id$
------------------------------------------------------------------------
  Dependency: none
------------------------------------------------------------------------
  If the user clicks on the search box when it has the value
  "Enter search here..." and the class is qdef then remove the contents
  so the search box is empty before typing commences...
----------------------------------------------------------------------*/

PageSmith.search_message = 'Enter search here...';

$('#search').submit(function () {
  if ($('#q').val() === '' || $('#q').val() === PageSmith.search_message) {
    window.alert("You must enter a search string");
    return false;
  }
});

$('#search_a').bind('click', function () {
  if ($('#q').val() === '' || $('#q').val() === PageSmith.search_message) {
    return false;
  }
  var uri = $(this).attr('href') + '?q=' + encodeURI($('#q').val());
  window.document.location = uri;
  return false;
});


$(function () {
  $('#q[value="' + PageSmith.search_message + '"]')
    .addClass('qdef')
    .on('focus', function () {
      $(this).removeClass('qdef').val('');
    });
});

$('div.collapsible h3, div.collapsible h4.keep').livequery(function () {
  $(this).prepend('<img src="/core/gfx/blank.gif" />').bind('click', function () {
    $(this).closest('div.collapsible').toggleClass('collapsed');
  });
});

$(function () {
  $('#collapse-all').on('click', function () {
    $('div.collapsible').addClass('collapsed');
    PageSmith.flags['t'] = 'c';
    PageSmith.setCookie();
  });
  $('#expand-all').on('click', function () {
    $('div.collapsible').removeClass('collapsed');
    PageSmith.flags['t'] = 'e';
    PageSmith.setCookie();
  });
  if (PageSmith.flags['t'] === 'c') {
    $('#collapse-all').trigger('click');
  } else {
    $('#expand-all').trigger('click');
  }
});

