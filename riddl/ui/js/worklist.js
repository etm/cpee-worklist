var base_url;

Prefill = function(what) {
  what(top,global);
};

$(document).ready(function() {// {{{  
  base_url= document.URL;
  $("input[name=base-url]").val(location.protocol + "//" + location.host + ":" + $('body').data('defaultport'));
  $("#arealogin > form").submit(function(event){ get_worklist(); event.preventDefault(); });
  if($.cookie("user") && $.cookie("domain")){
    $("input[name=domain-name]").val($.cookie("domain"));
    $("input[name=user-name]").val($.cookie("user"));
    get_worklist();
  }
  $("input[name=user-url]").val($("input[name=base-url]").val()+'/'+$("input[name=domain-name]").val()+'/'+$("input[name=user-name]").val());
  var url =$("input[name=user-url]").val()+'/tasks';
  $('.task_do').on('click',function(){
    var id = url + '/' + $(this).parents('tr').attr('data-id');
    take_work(id,$('.task_take',$(this).parent()),$('.task_giveback',$(this).parent()),1);
    do_work(id); 
  });
  $('.task_take').on('click',function(){
    var id = url + '/' + $(this).parents('tr').attr('data-id');
    take_work(id,$('.task_take',$(this).parent()),$('.task_giveback',$(this).parent()),1); 
  });
  $('.task_giveback').on('click',function(){
    var id = url + '/' + $(this).parents('tr').attr('data-id');
    take_work(id,$('.task_giveback',$(this).parent()),$('.task_take',$(this).parent()),0);
  });
});// }}}

function get_worklist() {// {{{
  var url =$("input[name=base-url]").val()+'/'+$("input[name=domain-name]").val()+'/'+$("input[name=user-name]").val()+'/tasks';
  // Set cookies
  $.cookie("user",$("input[name=user-name]").val());
  $.cookie("domain",$("input[name=domain-name]").val());
  // Finished Cookies

  console.log("SUCCESS");
  $.ajax({
    type: "GET", 
    url: url,
    dataType: "xml",
    success: function(res){
      
      $(".tabbed.hidden").removeClass("hidden");
      var ctv = $("#dat_tasks");
      ctv.empty();
      $(res).find('task').each(function(){
        var node = $("#dat_template_tasks tr").clone(true);
        var id = $(this).attr('id');
        node.attr('data-id',id);
        $('.name',node).text(id);
        if ($(this).attr('uid')=='*') {
          $('.task_giveback',node).prop('disabled', true);
        } else {
          $('.task_take',node).prop('disabled', true);
        }
        ctv.append(node);
      });
    },  
    error: function(a,b,c) {
      alert("Wrong Domain.");
    }
  });
}// }}}
  
function take_work(url,butt,butt2,give_or_take){ //{{{
  var op = give_or_take == 1 ? "take" : "giveback";
  $.ajax({
    type: "PUT",
    url: url,
    data:"operation="+op ,
    success: function(){
      $(butt).prop('disabled',true);
      $(butt2).prop('disabled',false);
      console.log("SUCCESS");
    },
    error: function(a,b,c){
      alert("Put didn't work");
    }
  });
} //}}}

function do_work(url) { //{{{
  // fill the global variable 'global' with the shit that is needed
  // create new tab
  // write form into the tab
  // ajax get the formhtml
  // insert formhtml into form (the javascript is automatically executed when you append/insert shit)
  // happiness
  $.ajax({
    type: "GET",
    url: url,
    data: "operation=json",
    success: function(res) {
      var postFormStr = "<form method='POST' onsubmit='' action='" + res.form + "'>\n";
      postFormStr += "<input type='hidden' name='url' value='" + res.url + "'></input>";
      postFormStr += "<input type='hidden' name='parameters' value='" + res.parameters + "'></input>";
      postFormStr += "<input type='hidden' name='baseurl' value='" + base_url + "'></input>";
      postFormStr += "<input type='hidden' name='wlurl' value='" + url + "'></input>";
      postFormStr += "</form>";
      var formElement = $(postFormStr);
      $('body').append(formElement);
      console.log(postFormStr);
      $(formElement).submit();
    },
    error: function(a,b,c) {
      alert ("Error while getting Task");
    }
  });
} //}}}
