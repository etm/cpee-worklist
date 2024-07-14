function toggle_message(message=undefined) { //{{{
  var url =$("input[name=base-url]").val()+'/'+$("input[name=user-name]").val()+'/';
  if ($("#dat_tasks tr").length == 0) {
    if (message != undefined) {
      $("#dat_message").text(message);
      $("#dat_message").show();
    } else {
      $.ajax({
        type: "GET",
        url: url,
        success: function(res){
          $("#dat_message").text(res);
          $("#dat_message").show();
        }
      });
    }
  } else {
    $("#dat_message").hide();
  }
} //}}}

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
            var node = $($("#dat_template_orgmodels")[0].content.cloneNode(true));
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
        if ($(this).attr('all') == "true") {
          var node = $($("#dat_template_tasks_multi")[0].content.cloneNode(true));
          $('.deadline',node).text($(this).attr('deadline'));
        } else {
          var node = $($("#dat_template_tasks_single")[0].content.cloneNode(true));
        }
        var taskidurl = $(this).attr('id');
        var tasklabel = $(this).attr('label');
        node.find('tr').attr('data-id',taskidurl);
        node.find('tr').attr('data-label',tasklabel);
        node.find('tr').addClass('priority_' + $(this).attr('priority'));
        $('.name',node).text(tasklabel);
        if ($(this).attr('own')=='true') {
          $('.task_take',node).prop('disabled', true);
        } else {
          $('.task_giveback',node).prop('disabled', true);
        }
        ctv.append(node);
      });
      toggle_message();
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
      $(butt2).removeAttr('disabled');
    },
    error: function(a,b,c){
      alert("Put didn't work");
    }
  });
} //}}}

function do_work(taskid,taskidurl) { //{{{
  $.ajax({
    type: "GET",
    url: taskidurl,
    success:function(res) {
      if (!uidash_add_tab("#main", res.label, taskid, true, '')) { return; };
      $.ajax({
        type: "GET",
        url: res.form,
        dataType: 'text',
        success: async (iform) => {
          let end = false;;
          let evaltext = '';
          let rel = res.form.match(/.*\//)[0];

          while (!end) {
            let matches = iform.match(/<worklist-form-load>(.*?)<\/worklist-form-load>/ms);
            if (matches && matches.length > 0) {
              evaltext += matches[1];
              iform = iform.replace(matches[0],'');
            } else {
              let includes = iform.match(/<\/?worklist-(relative-)?include\s+href=(("([^"]*)")|('([^']*)'))\s*\/?\s*>/ms);
              if (includes && includes.length > 0) {
                let inc;
                if (includes[1]) {
                  inc = rel + includes[4];
                } else {
                  inc = includes[4];
                }
                await $.ajax({
                  type: "GET",
                  url: inc,
                  dataType: 'text',
                  success: function(inctext) {
                    iform = iform.replace(includes[0],inctext);
                  }
                });
              } else {
                end = true;
              }
            }
          }
          {
            let replaces = iform.match(/form="worklist-form"/ms);
            if (replaces && replaces.length > 0) {
              iform = iform.replaceAll(replaces[0],'form="form_' + taskid + '"');
            }
          }
          {
            let replaces = iform.match(/div.task.current/ms);
            if (replaces && replaces.length > 0) {
              iform = iform.replaceAll(replaces[0],'div.task.task_' + taskid);
            }
          }
          {
            let replaces = iform.match(/worklist-item/ms);
            if (replaces && replaces.length > 0) {
              iform = iform.replaceAll(replaces[0],'div.task.task_' + taskid);
            }
          }
          {
            let replaces = evaltext.match(/worklist-item/ms);
            if (replaces && replaces.length > 0) {
              evaltext = evaltext.replaceAll(replaces[0],'div.task.task_' + taskid);
            }
          }

          let container = $("<div class='task task_" + taskid + "'><form id='form_" + taskid + "'></form></div>");
          container.append(iform);

          let form = $("ui-area[data-belongs-to-tab="+taskid+"]");
              form.addClass('areataskitem');
          let data;
          try { data = res.parameters; } catch (e) { data = {}; }
          form.append(container);

          eval(evaltext); // investigate indirect eval and strict

          uidash_activate_tab($('ui-tabbar ui-tab[data-tab=' + taskid + ']'));
          $("#form_"+taskid).on('submit',function(e){
            let scount = 0;
            $('select[required][form="form_' + taskid + '"]').each((_,e) => {
              if ($(e).val() == null) { scount += 1; }
              if (scount == 1) {
                $(e).focus();
                $(e).removeClass('pulseit');

                setTimeout(()=>{$(e).addClass('pulseit')},100);;
              }
            });
            if (scount > 0) {
              e.preventDefault();
              return false;
            }
            var form_data = $(this).serializeArray();
            var send_data = {};
            var headers = {};
            if (res.collect) { headers['CPEE-UPDATE'] = 'true'; }
            send_data['user'] = $("input[name=user-name]").val();
            send_data['raw'] = form_data;
            send_data['data'] = {};
            $.map(send_data['raw'], function(n, i){
                send_data['data'][n['name']] = n['value'];
            });
            $.ajax({
              type: "PUT",
              url: res.url,
              headers: headers,
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
    data: "topic=user&events=status,take,giveback,finish&topic=task&events=add,delete",
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
                  if (data.content.user == $("input[name=user-name]").val()) {
                    tr.remove();
                    toggle_message();
                  }
                  break;
                case 'status':
                  toggle_message(data.content.status);
                  break;
                case 'take':
                case 'giveback':
                  if (data.content.user != $("input[name=user-name]").val()) {
                    tr.remove();
                    get_worklist();
                  }
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
                  toggle_message();
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

