$('body').prepend('<span class="dev-toggle devpanel">hide dev</span><span class="dev-toggle devpanel" style="display:none">show dev</span>');
$('.dev-toggle').live('click', function () {
  $('.devpanel').toggle();
});
