(function(){
  'use strict';
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

  Pagesmith.search_message = 'Enter search here...';

  $('#search').submit(function () {
    if ($('#q').val() === '' || $('#q').val() === Pagesmith.search_message) {
      window.alert('You must enter a search string');
      return false;
    }
  });
  $(function () {
    $('#q[value="' + Pagesmith.search_message + '"]')
      .addClass('qdef')
      .on('focus', function () {
        $(this).removeClass('qdef').val('');
      });
  });
}(jQuery));
