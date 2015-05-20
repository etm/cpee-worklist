$(document).ready(function() {// {{{  
  $("input[name=base-url]").val(location.protocol + "//" + location.host + ":" + $('body').data('defaultport'));
  $("#arealogin > form").submit(function(event){ 
    get_worklist(); 
    subscribe_worklist($.cookie("domain"));
    ui_toggle_vis_tab($("#worklist .switch"));
    event.preventDefault(); 
  });
  if($.cookie("user") && $.cookie("domain")){
    $("input[name=domain-name]").val($.cookie("domain"));
    $("input[name=user-name]").val($.cookie("user"));
    ui_toggle_vis_tab($("#worklist .switch"));
    get_worklist();
    subscribe_worklist($.cookie("domain"));
  }
  $(document).on('click','.orgmodeltab',function(event){
    var id = $(this).attr('data-tab');
    ui_empty_tab_contents(id);
    // TODO Hier kommt Raphi
  });
  $(document).on('click','#orgmodels li a.model',function(event){
    var id = $(this).attr('href').hashCode();
    if (!ui_add_tab("#main", "Orgmodel Oida", id, true, 'orgmodeltab')) {
      ui_empty_tab_contents(id);
    }
    // TODO Hier kommt Raphi
    event.preventDefault(); 
  });
  $(document).on('click','.task_do',function(){
    var url =$("input[name=user-url]").val()+'/tasks';
    var taskid = $(this).parents('tr').attr('data-id');
    var taskidurl = url + '/' + taskid;
    take_work(taskidurl,$('.task_take',$(this).parent()),$('.task_giveback',$(this).parent()),1);
    do_work(taskid,taskidurl); 
  });
  $(document).on('click','.task_take',function(){
    var url =$("input[name=user-url]").val()+'/tasks';
    var taskid = $(this).parents('tr').attr('data-id');
    var taskidurl = url + '/' + taskid;
    take_work(taskidurl,$('.task_take',$(this).parent()),$('.task_giveback',$(this).parent()),1); 
  });
  $(document).on('click','.task_giveback',function(){
    var url =$("input[name=user-url]").val()+'/tasks';
    var taskid = $(this).parents('tr').attr('data-id');
    var taskidurl = url + '/' + taskid;
    take_work(taskidurl,$('.task_giveback',$(this).parent()),$('.task_take',$(this).parent()),0);
  });

});// }}}

function get_worklist() {// {{{
  $("input[name=user-url]").val($("input[name=base-url]").val()+'/'+$("input[name=domain-name]").val()+'/'+$("input[name=user-name]").val());
  var url =$("input[name=base-url]").val()+'/'+$("input[name=domain-name]").val()+'/'+$("input[name=user-name]").val()+'/tasks';
  if(!($.cookie("user") && $.cookie("domain"))){
    subscribe_worklist($("input[name=domain-name]").val());
  }
  // Set cookies
  $.cookie("user",$("input[name=user-name]").val());
  $.cookie("domain",$("input[name=domain-name]").val());
  // Finished Cookies

  $.ajax({
    type: "GET", 
    url: url,
    dataType: "xml",
    success: function(res){
      
      $('#taborganisation').removeClass("hidden");
      $.ajax({
        type: "GET",
        url: $("input[name=base-url]").val()+'/'+$("input[name=domain-name]").val()+'/orgmodels',
        dataType: "xml",
        success: function(res){
          var ctv = $("#orgmodels");
          ctv.empty();
          $(res).find('orgmodel').each(function(){
            var uri = decodeURIComponent($(this).text());
            var node = $("#dat_template_orgmodels li").clone(true);
            $('.link',node).text(uri);
            $('.link',node).attr('href',uri);
            $('.model',node).attr('href',uri);
            ctv.append(node);
          });
        }
      });
      $("#main").removeClass("hidden");
      var ctv = $("#dat_tasks");
      ctv.empty();
      $(res).find('task').each(function(){
        var node = $("#dat_template_tasks tr").clone(true);
        var taskidurl = $(this).attr('id');
        var tasklabel = $(this).attr('label');
        node.attr('data-id',taskidurl);
        node.attr('data-id',taskidurl);
        $('.name',node).text(tasklabel);
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
  console.log(url);
  console.log(op);
  $.ajax({
    type: "PUT",
    url: url,
    data:"operation="+op ,
    success: function(){
      $(butt).prop('disabled','true');
      $(butt2).prop('disabled','false');
    },
    error: function(a,b,c){
      alert("Put didn't work");
    }
  });
} //}}}

function do_work(taskid,taskidurl) { //{{{
  var form_html;
  $.ajax({
    type: "GET",
    url: taskidurl,
    success:function(res) {
      if (!ui_add_tab("#main", res.label, taskid, true, '')) return;
      $.ajax({
        type: "GET",
        url: res.form,
        success: function(form) {
          var postFormStr = "<form id='form_" + taskid + "'>";
          form_html=form;
          postFormStr += form_html + "</form>";
          var data = JSON.parse(res.parameters);
          var form_area = "ui-area[data-belongs-to-tab="+taskid+"]";
          $(form_area).append(postFormStr);
          eval($('worklist-form-load').text()); //TODO, da werden alle worklist for loads in allen tabs, nur den aktuellen
          $('worklist-form-load').hide();
          console.log($("#form_"+taskid));
          $("#form_"+taskid).on('submit',function(e){
            // Form data
            var form_data = $(this).serialize();
            // res.url == Cpee Callback url
            $.ajax({
              type: "PUT",
              url: res.url,
              data: form_data,
              success: function(something){
                $.ajax({
                  type: "DELETE",
                  url: taskidurl,
                  success: function(del){
                    ui_close_tab('ui-tab[data-tab='+taskid+'] ui-close');
                    get_worklist();
                  },
                  error: function(a,b,c){
                    console.log("Delete failed");
                  }
                });
              },
              error: function(a,b,c){
                console.log("Put didnt work");
              }
            });
            e.preventDefault(); 
          });
        },
        error: function(a,b,c){
          console.log("Error while getting form html");
        }
      });
    },
    error: function(a,b,c){
      console.log("Error while getting url for form");
    }
  });
} //}}}

function subscribe_worklist(){ //{{{
  var url = $("input[name=base-url]").val()+'/'+$("input[name=domain-name]").val()+'/notifications/subscriptions/';
  $.ajax({
    type: "POST",
    url: url,
    data: "topic=user&events=take,giveback,finish&topic=task&events=add,delete",
    success: function(ret){
      var Socket = "MozWebSocket" in window ? MozWebSocket : WebSocket;
      var subscription = $.parseQuery(ret)[0].value;
      ws = new Socket(url.replace(/http/,'ws') + subscription + "/ws/");
      ws.onmessage = function(e) {
        data = $.parseXML(e.data);
        if ($('event > topic',data).length > 0) {
          var cid = JSON.parse($('event > notification',data).text()).index;
          var tr = $('tr[data-id="'+cid+'"]');
          switch($('event > topic',data).text()) {
            case 'user':
              switch($('event > event',data).text()) {
                case 'finish':
                  tr.remove();
                  break;
                default:
                  get_worklist();
                  break;
              }
              break;
            case 'task':
              switch($('event > event',data).text()) {
                case 'add':
                  get_worklist();
                  break;
                case 'delete':
                  tr.remove();
                  break;
              }
              break;
          }
        }
      };
    },
    error: function(){
      console.log("Not Successful subscribed");
    }
  });
} //}}}

String.prototype.hashCode = function() { //{{{
  var hash = 0, i, chr, len;
  if (this.length == 0) return hash;
  for (i = 0, len = this.length; i < len; i++) {
    chr   = this.charCodeAt(i);
    hash  = ((hash << 5) - hash) + chr;
    hash |= 0; // Convert to 32bit integer
  }
  return hash;
}; //}}}
