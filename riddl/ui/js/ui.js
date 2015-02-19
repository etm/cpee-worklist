$(document).ready(function() {
  if (!($.browser.name == "Firefox" && $.browser.version >= 20) && !($.browser.name == "Chrome" && $.browser.version >= 30)) {
    $('body').children().remove();
    $('body').append('Sorry, only Firefox >= 20.0 and Chrom(e|ium) >= 17 for now.');
  }  
});
