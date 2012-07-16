var div_counter = 0;
$('.editable_panel').livequery(function () {
  if (!$(this).attr('id')) {
    div_counter++;
    $(this).attr('id', 'editable_' + div_counter);
  }
  $(this).append('<span class="edit_link" rel="Panel ' + $(this).attr('id') + '" title="Edit panel ' + $(this).attr('id') + '">Edit</span>');
});
