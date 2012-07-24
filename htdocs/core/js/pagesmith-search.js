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
    .live('focus', function () {
      $(this).removeClass('qdef').val('');
    });
});

$('div.collapsible h3, div.collapsible h4.keep').livequery(function () {
  $(this).prepend('<img src="/core/gfx/blank.gif" />').bind('click', function () {
    $(this).closest('div.collapsible').toggleClass('collapsed');
  });
});
$(function () {
  $('#collapse-all').live('click', function () {
    $('div.collapsible').addClass('collapsed');
    PageSmith.flags[$('body').attr('id') === 'searchindex' ? 's' : 't'] = 'c';
    PageSmith.setCookie();
  });
  $('#expand-all').live('click', function () {
    $('div.collapsible').removeClass('collapsed');
    PageSmith.flags[$('body').attr('id') === 'searchindex' ? 's' : 't'] = 'e';
    PageSmith.setCookie();
  });
  if (PageSmith.flags[$('body').attr('id') === 'searchindex' ? 's' : 't'] === 'c') {
    $('#collapse-all').trigger('click');
  } else {
    $('#expand-all').trigger('click');
  }
});

$(function () {
  var a, new_html, value;
  if ($('#q_db')) {
    //Get set value from cookie!
    if (PageSmith.flags.sd) {
      $('#q_db').val(PageSmith.flags.sd);
    }
    if (typeof document.body.style.maxHeight === "undefined") {
      $('#q_db').change(function () {
        PageSmith.flags.sd = $('#q_db').val();
        PageSmith.setCookie();
      });
      return;
    }

    $('#q_db').hide();
    a = $('#q_db').find('option');
    new_html = [];
    value = $('#q_db').val();

    a.each(function () {
      var x = $(this).val(), t = $(this).text(), v;
      if (value === '') {
        value = x;
      }
      while (t !== v) {
        v = t;
        t = t.replace(/^(\.*)\./, '$1&nbsp;&nbsp;');
      }
      if (x === value) {
        new_html.unshift('<li class="first s_' + x + '">' + t + '</li>');
      }
      new_html.push('<li class="s_' + x + '">' + t + '</li>');
    });

    $('#s2')
      .append('<ul>' + new_html.join('') + '</ul>')
      .find('ul')
      .mouseleave(function () {
        $(this).removeClass('xp');
      })
      .find('li').click(function () {
        var this_li = $(this), m;
        if (this_li.closest('ul').hasClass('xp')) {
          m = this_li.attr('class').match(/\bs_(\w+)/);
          if (m) {
            $('#q_db').val(m[1]);
            PageSmith.flags.sd = m[1];
            PageSmith.setCookie();
            $(this_li.closest('ul').find('li')[0])
              .attr('class', 'first s_' + m[1])
              .text(this_li.text());
          }
          this_li.closest('ul').removeClass('xp');
        } else {
          this_li.closest('ul').addClass('xp');
        }
      });
  }
});
