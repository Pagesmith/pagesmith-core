var div_counter = 0;
$('div.editable').livequery(function () {
  if (!$(this).attr('id')) {
    div_counter++;
    $(this).attr('id', 'editable_' + div_counter);
  }
  $(this).append('<span class="edit_block" rel="Panel ' + $(this).attr('id') + '" title="Edit panel ' + $(this).attr('id') + '">Edit</span>');
});

$('h1.editable, h2.editable, h3.editable, p.editable').css({border: '1px solid red'}).append('<span class="edit_block" rel="Paragraph" title="Paragraph">Edit</span>');

var bgcol = '#ffcccc';
$('dl.editable dt').each(function (i, n) {
  $(n).css({border: '1px solid red', backgroundColor: bgcol}).nextUntil('dt').css({border: '1px solid green', backgroundColor: bgcol}).last().append('<span class="edit_block" rel="Paragraph" title="Paragraph">Edit</span>');
  bgcol = bgcol === '#ffcccc' ? '#ccffcc' : '#ffcccc';
});
$('div.createable').livequery(function () {
  $(this).append('<span class="edit_block" rel="Panel ' + $(this).attr('id') + '" title="Add panel">Add</span>');
});
