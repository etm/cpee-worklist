$(document).ready(function() {// {{{
  $("input[name=base-url]").val(location.protocol + "//" + location.host + '/worklist/server');
  $("#arealogin > form").submit(function(event){
    get_worklist();
    subscribe_worklist();
    uidash_toggle_vis_tab($("#worklist .switch"));
    event.preventDefault();
  });
  var q = $.parseQuerySimple();
  if (q.user) {
    $("input[name=user-name]").val(q.user);
    uidash_toggle_vis_tab($("#worklist .switch"));
    get_worklist();
    subscribe_worklist();
  }
  $(document).on('click','.orgmodeltab',function(event){
    var id = $(this).attr('data-tab');
    uidash_empty_tab_contents(id);
    // TODO Hier kommt Raphi
  });
  $(document).on('click','#orgmodels li a.model',function(event){
    // var id = $(this).attr('href').hashCode();
    // if (!uidash_add_tab("#main", "Orgmodel", id, true, 'orgmodeltab')) {
    //   uidash_empty_tab_contents(id);
    // }
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
  $("input[name=user-url]").val($("input[name=base-url]").val()+'/'+$("input[name=user-name]").val());
  var url =$("input[name=base-url]").val()+'/'+$("input[name=user-name]").val()+'/tasks';
  // subscribe_worklist($("input[name=domain-name]").val());
  // Set url (no more cookie nonsense!)
  history.replaceState({}, '', '?user='+encodeURIComponent($("input[name=user-name]").val()));

  $.ajax({
    type: "GET",
    url: url,
    dataType: "xml",
    success: function(res){

      $('#taborganisation').removeClass("hidden");
      $.ajax({
        type: "GET",
        url: $("input[name=base-url]").val()+'/orgmodels/',
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
      alert("Server not running.");
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
      if (!uidash_add_tab("#main", res.label, taskid, true, '')) { return; };
      $.ajax({
        type: "GET",
        url: res.form,
        dataType: 'html',
        success: function(iform) {
          let iform_element = $("<form id='form_" + taskid + "'></form>");
          iform_element.append(iform);
          const iform_evaltext = $('worklist-form-load',iform_element).text();
          $('worklist-form-load',iform_element).remove()

          let form = $("ui-area[data-belongs-to-tab="+taskid+"]");
          let data;
          try { data = JSON.parse(res.parameters); } catch (e) { data = {}; }
          form.append(iform_element);

          eval(iform_evaltext); // investigate indirect eval and strict

          uidash_activate_tab($('ui-tabbar ui-tab[data-tab=' + taskid + ']'));
          $("#form_"+taskid).on('submit',function(e){
            var form_data = $(this).serializeArray();
            var send_data = {};
            send_data['user'] = $("input[name=user-name]").val();
            send_data['raw'] = form_data;
            send_data['data'] = {};
            $.map(send_data['raw'], function(n, i){
                send_data['data'][n['name']] = n['value'];
            });
            $.ajax({
              type: "PUT",
              url: res.url + '/',
              contentType: "application/json",
              data: JSON.stringify(send_data),
              success: function(something){
                $.ajax({
                  type: "DELETE",
                  url: taskidurl,
                  success: function(del){
                    uidash_close_tab('ui-tab[data-tab='+taskid+'] ui-close');
                    get_worklist();
                  },
                  error: function(a,b,c){
                    console.log("Delete failed");
                  }
                });
              },
              error: function(a,b,c){
                $.ajax({
                  type: "DELETE",
                  url: taskidurl,
                  success: function(del){
                    uidash_close_tab('ui-tab[data-tab='+taskid+'] ui-close');
                    get_worklist();
                  },
                  error: function(a,b,c){
                    console.log("Delete failed");
                  }
                });
                // TODO
                console.log("Put didnt work");
              }
            });
            e.preventDefault();
          });
        },
        error: function(a,b,c){
          $.ajax({
            type: "DELETE",
            url: taskidurl,
            success: function(del){
              uidash_close_tab('ui-tab[data-tab='+taskid+'] ui-close');
              get_worklist();
            },
            error: function(a,b,c){
              console.log("Delete failed");
            }
          });
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
  var url = $("input[name=base-url]").val()+'/notifications/subscriptions/';
  $.ajax({
    type: "POST",
    url: url,
    data: "topic=user&events=take,giveback,finish&topic=task&events=add,delete",
    success: function(ret){
      subscription = ret;
      es = new EventSource(url + subscription + "/sse/");
      es.onopen = function() { };
      es.onmessage = function(e) {
        data = JSON.parse(e.data);
        if (data['type'] == 'event') {
          var cid = data.content.callback_id;
          var tr = $('tr[data-id="'+cid+'"]');
          switch(data['topic']) {
            case 'user':
              switch(data['name']) {
                case 'finish':
                  tr.remove();
                  break;
                default:
                  tr.remove();
                  get_worklist();
                  break;
              }
              break;
            case 'task':
              switch(data['name']) {
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
      es.onerror = function(e){ }
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

