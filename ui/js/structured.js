/*
  This file is part of CPEE-WORKLIST.

  CPEE-WORKLIST is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the Free
  Software Foundation, either version 3 of the License, or (at your option) any
  later version.

  CPEE-WORKLIST is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
  PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along with
  CPEE-WORKLIST (file LICENSE in the main directory).  If not, see
  <http://www.gnu.org/licenses/>.
*/

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

function config_defaults() { //{{{
  var default_values = {};
  if (location.protocol.match(/^file/)) {
    default_values['base-url'] = 'http://localhost:9298/';
  } else {
    default_values['base-url']  = location.protocol + "//" + location.hostname + '/worklist/server';
  }
  default_values['names'] = 2;
  return default_values;
} //}}}

$(document).ready(function() {// {{{
  var q = $.parseQuerySimple();
  $.ajax({
    url: $('body').attr('data-defaultconfig'),
    success: function(res){
      var res_def = config_defaults();
      if (res['base-url']) { res_def['base-url'] = res['base-url']; }
      if (res['names']) { res_def['names'] = res['names']; }

      $('body').attr('data-names', res_def['names']);
      $('input[name=base-url]').val(res_def['base-url']);

      if (q.user) {
        $("input[name=user-name]").val(q.user);
        uidash_toggle_vis_tab($("#worklist .switch"));
        get_worklist();
        subscribe_worklist();
      }
    },
    error: function(){
      var res = config_defaults();
      $('body').attr('data-names', res_def['names']);
      $('input[name=base-url]').val(res_def['base-url']);
    }
  });

  $("#arealogin > form").submit(function(event){
    get_worklist();
    subscribe_worklist();
    uidash_toggle_vis_tab($("#worklist .switch"));
    event.preventDefault();
  });
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
    take_work(taskidurl,$(this).parents('tr'),1);
    do_work(taskid,taskidurl);
  });
  $(document).on('click','.task_continue',function(){
    var url =$("input[name=user-url]").val()+'/tasks';
    var taskid = $(this).parents('tr').attr('data-id');
    var taskidurl = url + '/' + taskid;
    do_work(taskid,taskidurl);
  });
  $(document).on('click','.task_take',function(){
    var url =$("input[name=user-url]").val()+'/tasks';
    var taskid = $(this).parents('tr').attr('data-id');
    var taskidurl = url + '/' + taskid;
    take_work(taskidurl,$(this).parents('tr'),1);
  });
  $(document).on('click','.task_giveback',function(){
    var url =$("input[name=user-url]").val()+'/tasks';
    var taskid = $(this).parents('tr').attr('data-id');
    var taskidurl = url + '/' + taskid;
    take_work(taskidurl,$(this).parents('tr'),0);
  });

});// }}}
function place_worklist_item(node,own) {
  let prio = node.attr('data-priority');
  let prioz = node.attr('data-prioritization');

  if (own == 'true') {
    $('.task_do',node).addClass('hidden');
    $('.task_continue',node).removeClass('hidden');
    $('.task_giveback',node).removeClass('hidden');
  } else {
    $('.task_do',node).removeClass('hidden');
    $('.task_continue',node).addClass('hidden');
    $('.task_giveback',node).addClass('hidden');
  }

  let ctv;
  if (prio == 1) {
    ctv = $("#dat_tasks_priority_high");
  } else {
    if (own == 'true') {
      ctv = $("#dat_tasks_own");
    } else {
      if (prioz == '' || prioz.match($("input[name=user-name]").val())) {
        ctv = $("#dat_tasks_priority");
      } else {
        ctv = $("#dat_tasks_others");
      }
    }
  }
  ctv.append(node);
  if (!$('#dat_tasks_priority_high').is(':empty')) { $('#dat_tasks_priority_high_head').removeClass('hidden'); } else { $('#dat_tasks_priority_high_head').addClass('hidden'); }
  if (!$('#dat_tasks_priority').is(':empty'))      { $('#dat_tasks_priority_head').removeClass('hidden'); }      else { $('#dat_tasks_priority_head').addClass('hidden'); }
  if (!$('#dat_tasks_own').is(':empty'))           { $('#dat_tasks_own_head').removeClass('hidden'); }           else { $('#dat_tasks_own_head').addClass('hidden'); }
  if (!$('#dat_tasks_others').is(':empty'))        { $('#dat_tasks_others_head').removeClass('hidden'); }        else { $('#dat_tasks_others_head').addClass('hidden'); }
  if (!$('#dat_tasks_others_work').is(':empty'))   { $('#dat_tasks_others_work_head').removeClass('hidden'); }   else { $('#dat_tasks_others_work_head').addClass('hidden'); }
}

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

      $('#dat_tasks_priority_high').empty();
      $('#dat_tasks_priority').empty();
      $('#dat_tasks_own').empty();
      $('#dat_tasks_others').empty();
      $('#dat_tasks_others_work').empty();

      $('#dat_tasks_priority_high_head').addClass('hidden');
      $('#dat_tasks_priority_head').addClass('hidden');
      $('#dat_tasks_own_head').addClass('hidden');
      $('#dat_tasks_others_head').addClass('hidden');
      $('#dat_tasks_others_work_head').addClass('hidden');

      $(res).find('task').each(function(){
        if ($(this).attr('all') == "true") {
          var node = $($("#dat_template_tasks_multi")[0].content.cloneNode(true));
          $('.deadline span',node).text($(this).attr('deadline'));
        } else {
          var node = $($("#dat_template_tasks_single")[0].content.cloneNode(true));
        }
        let nam = $('.name',node)[0];
        for (let i = 0; i < $('body').attr('data-names') - 1; i++) {
          let n = nam.cloneNode(true);
          $(nam).after(n);
        }
        node.find('tr').attr('data-id',$(this).attr('id'));
        node.find('tr').attr('data-label',$(this).attr('label'));
        node.find('tr').attr('data-priority',$(this).attr('priority'));
        node.find('tr').attr('data-prioritization',$(this).attr('prioritization'));
        node.find('tr').addClass('priority_' + $(this).attr('priority'));

        let i = 1;
        $(this).attr('label').split(':').forEach( e => {
          $('.name:nth-child(' + i + ')',node).text(e);
          i++;
        });
        $('.name:nth-child(' + i + ')',node).text($(this).attr('label_extension'));

        place_worklist_item(node.find('tr'),$(this).attr('own'));
      });
      toggle_message();
    },
    error: function(a,b,c) {
      alert("Server not running.");
    }
  });
}// }}}

function take_work(url,node,give_or_take){ //{{{
  var op = give_or_take == 1 ? "take" : "giveback";
  $.ajax({
    type: "PUT",
    url: url,
    data:"operation="+op ,
    success: function(){
      if (op == "take") {
        place_worklist_item(node,'true');
      } else if (op == "giveback") {
        place_worklist_item(node,'false');
      }
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
            let replaces = iform.match(/worklist-item/ms);
            if (replaces && replaces.length > 0) {
              iform = iform.replaceAll(replaces[0],'body');
            }
          }
          {
            let replaces = evaltext.match(/worklist-item/ms);
            if (replaces && replaces.length > 0) {
              evaltext = evaltext.replaceAll(replaces[0],'body');
            }
          }

          let worklist_form = $("<form id='worklist-form'></form>");

          let data;
          try { data = res.parameters; } catch (e) { data = {}; }

          let iframe= $('<iframe src="container.html"></iframe>')[0];
              iframe.onload = () => {
                $(iframe.contentDocument.body).append(worklist_form);
                $(iframe.contentDocument.body).append(iform);

                iframe.contentWindow.data = data;
                iframe.contentWindow.form = $(iframe.contentDocument.body);

                // investigate indirect eval and strict
                iframe.contentWindow.eval(evaltext),

                $("#worklist-form",iframe.contentWindow.form).on('submit',function(e){

                  let scount = 0;
                  $('select[required][form="worklist-form"]',iframe.contentWindow.form).each((_,e) => {
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
              }

          let taskitem = $("ui-area[data-belongs-to-tab="+taskid+"]");
              taskitem.addClass('areataskitem');
          taskitem.append(iframe);

          uidash_activate_tab($('ui-tabbar ui-tab[data-tab=' + taskid + ']'));
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

