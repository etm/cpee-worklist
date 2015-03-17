function ui_click_tab(moi) { // {{{
  $(moi).trigger('click');
} // }}}

function ui_activate_tab(moi) { // {{{
  var active = $(moi).attr('id').replace(/tab/,'');
  var tab = $(moi).parent().parent().parent().parent();
  var tabs = [];
  $("td.tab",tab).each(function(){
    if (!$(this).attr('class').match(/switch/))
      tabs.push($(this).attr('id').replace(/tab/,''));
  });  
  $(".inactive",tab).removeClass("inactive");
  $.each(tabs,function(a,b){
    if (b != active) {
      $("#tab" + b).addClass("inactive");
      $("#area" + b).addClass("inactive");
    }  
  });
  ui_rest_resize();
} // }}}
function ui_activate_section(section) {
    section.parent().children().each(function() {
        if(!$(this).hasClass("hidden"))
            $(this).addClass("hidden");
    });
    section.removeClass("hidden");
}
function ui_toggle_vis_tab(moi) {// {{{
  var tabbar = $(moi).parent().parent().parent();
  var tab = $(tabbar).parent();
  var fix = $(tab).parent();
  $('h1',moi).toggleClass('margin');
  $("tr.border",tabbar).toggleClass('hidden');
  $("div.tabbelow",tab).toggleClass('hidden');
  $("td.tabbehind button",tabbar).toggleClass('hidden');
  if ($(fix).attr('class') && $(fix).attr('class').match(/fixedstate/)) {
    $(".fixedstatehollow").height($(fix).height());
  }  
  ui_rest_resize();
}// }}}

function ui_rest_resize() {
  if ($('div.tabbed.rest .tabbar')) {
    var theight = $(window).height() - $('div.tabbed.rest .tabbar').offset().top - $('div.tabbed.rest .tabbar').height();
    $('div.tabbed.rest .tabbelow').height(theight);
    $('div.tabbed.rest .tabbelow .column').height(theight);
  }  
}  

function ui_close_tab(moi){
  var active = $(moi).parent().attr('id').replace(/tab/,'');
  var is_inactive = $(moi).parent().hasClass('inactive');
  $('#area' + active).remove();
  $('#tab' + active).remove();
  if (!is_inactive)
    ui_click_tab($('.tabbed table.tabbar td.tab.default'));
}

function ui_add_close(moi) {
  $(moi).append($('<span class="close">✖</span>'));
}

function ui_add_tab(tabbar,title,id,closeable,additionalclasses) {
  additionalclasses = typeof additionalclasses !== 'undefined' ? additionalclasses : '';
  var instab = $("<td class='tab inactive" + (closeable ? ' closeable' : '') + (additionalclasses == '' ? '' : ' ' + additionalclasses) + "' id='tab_" + id + "'><h1>" + title + "</h1></td>");
  var insarea = $("<div id='area_" + id + "' class='inactive'></div>");
  $(tabbar).find('tr td.tabbehind').before(instab);
  $(tabbar).find('.tabbelow').append(insarea);
  ui_add_close($('#tab_' + id));
}

function ui_clone_tab(tabbar,original,title,id,closeable,additionalclasses) {
    additionalclasses = typeof additionalclasses !== 'undefined' ? additionalclasses : '';
    var instab = $("<td class='tab inactive" + (closeable ? ' closeable' : '') + (additionalclasses == '' ? '' : ' ' + additionalclasses) + "' id='tab_" + id + "'><h1>" + title + "</h1></td>");
    var insarea = original.clone();
    insarea.attr("id","area_"+id);
    insarea.attr("class","inactive");
    $(tabbar).find('tr td.tabbehind').before(instab);
    $(tabbar).parent('.tabbed').find('.tabbelow').append(insarea);
    ui_add_close($('#tab_' + id));
}

$(document).ready(function() {
  $(window).resize(ui_rest_resize);
  $('.tabbed table.tabbar td.tab.switch').click(function(){ui_toggle_vis_tab(this);});
  $(document).on('click','.tabbed table.tabbar td.tab:not(.switch)',function(){ui_activate_tab(this);});
  ui_add_close($('.tabbed table.tabbar td.tab.closeable'));
  $(document).on('click','.tabbed table.tabbar td.tab.closeable .close',function(){ui_close_tab(this);});
});
