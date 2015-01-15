var ws;
var running = false;
var graphrealization;
var subscription;
var subscription_state = 'less';
var save = {};
    save['state']= undefined;
    save['dsl'] = undefined;
    save['endpoints'] = undefined;
    save['dataelements'] = undefined;
    save['details'] = undefined;
var node_state = {};
var base_url;
var sub_more = 'topic'  + '=' + 'running' + '&' +// {{{
               'events' + '=' + 'activity_calling,activity_manipulating,activity_failed,activity_done' + '&' +
               'topic'  + '=' + 'running' + '&' +
               'votes'  + '=' + 'syncing_after' + '&' +
               'topic'  + '=' + 'properties/description' + '&' +
               'events' + '=' + 'change,error' + '&' +
               'topic'  + '=' + 'properties/position' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/state' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/dataelements' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/endpoints' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/transformation' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/handlerwrapper' + '&' +
               'events' + '=' + 'result' + '&' +
               'topic'  + '=' + 'properties/handlers' + '&' +
               'events' + '=' + 'change';// }}}
var sub_less = 'topic'  + '=' + 'running' + '&' +// {{{
               'events' + '=' + 'activity_calling,activity_manipulating,activity_failed,activity_done' + '&' +
               'topic'  + '=' + 'properties/position' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/description' + '&' +
               'events' + '=' + 'change,error' + '&' +
               'topic'  + '=' + 'properties/state' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/dataelements' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/endpoints' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/transformation' + '&' +
               'events' + '=' + 'change' + '&' +
               'topic'  + '=' + 'properties/handlerwrapper' + '&' +
               'events' + '=' + 'result' + '&' +
               'topic'  + '=' + 'properties/handlers' + '&' +
               'events' + '=' + 'change';// }}}

$(document).ready(function() {// {{{
  base_url= document.URL;
  $("input[name=base-url]").val(location.protocol + "//" + location.host + ":" + $('body').data('defaultport'));
  $("#arealogin > form").submit(function(event){ get_worklist(); event.preventDefault(); });
  $("button[name=instance]").click(function(){ monitor_instance(false); });
});// }}}

function check_subscription() { // {{{
  var url = $("input[name=current-instance]").val();
  var num = 0;
  if ($("input[name=votecontinue]").is(':checked')) num += 1;
  if (num > 0 && subscription_state == 'less') {
    $.ajax({
      type: "PUT", 
      url: url + "/notifications/subscriptions/" + subscription,
      data: (
        'message-uid' + '=' + 'xxx' + '&' +
        sub_more + '&' +
        'fingerprint-with-producer-secret' + '=' + 'xxx'
      )
    });
    subscription_state = 'more';
  }  
  if (num == 0 && subscription_state == 'more') {
    $.ajax({
      type: "PUT", 
      url: url + "/notifications/subscriptions/" + subscription,
      data: (
        'message-uid' + '=' + 'xxx' + '&' +
        sub_less + '&' +
        'fingerprint-with-producer-secret' + '=' + 'xxx'
      )
    });  
    subscription_state = 'less';
    format_visual_vote_clear();
  }  
}// }}}

function get_worklist() {// {{{
  var url =$("input[name=base-url]").val()+'/'+$("input[name=domain-name]").val()+'/'+$("input[name=user-name]").val()+'/tasks';
  console.log("SUCCESS");
  $.ajax({
    type: "GET", 
    url: url,
    dataType: "xml",
    success: function(res){
      $(".tabbed.hidden").removeClass("hidden");
      var ctv = $("#dat_dataelements");
      ctv.empty();
      $(res).find('task').each(function(){
        var node = $("#dat_template_pair tr").clone(true);
        var id = $(this).attr('id');
        var button_take = $('.pair_take',node);
        var button_giveback = $('.pair_giveback',node);
        $('.pair_name',node).val(id);
        button_take.click(function(){ take_work(url + '/' + id,button_take,button_giveback,1); });
        button_giveback.click(function(){ take_work(url + '/' + id,button_giveback,button_take,0); });
        $('.pair_do',node).click(function(){ take_work(url + '/' + id,button_take,button_giveback,1); do_work(url + '/' + id); });
        if ($(this).attr('uid')=='*') {
          $('.pair_giveback',node).prop('disabled', true);
        } else {
          $('.pair_take',node).prop('disabled', true);
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

    
  $.ajax({
    type: "GET",
    url: url,
    data: "operation=json",
    success: function(res) {
      var postFormStr = "<form method='POST' action='" + res.form + "'>\n";
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


function monitor_instance(load) {// {{{
  var url = $("input[name=instance-url]").val();

  $('.tabbehind button').hide();
  $('#dat_details').empty();

  $.ajax({
    type: "GET", 
    url: url + "/tasks",
    success: function(res){
      console.log("SUCCES WL");
      $(".tabbed.hidden").removeClass("hidden");
      //$(".tabbed .tab.hidden").removeClass("hidden");

      // Change url to return to current instance when reloading
      $("input[name=current-instance]").val(url);
      $("#current-instance").text(url);
      $("#current-instance").attr('href',url);
      //history.replaceState({}, '', '?monitor='+url);

      // Change url to return to current instance when reloading (because new subscription is made)
      //$("input[name=votecontinue]").removeAttr('checked');
      //subscription_state = 'less';
/*
      $.ajax({
        type: "POST", 
        url: url + "/notifications/subscriptions/",
        data: sub_less,
        success: function(res){
          res = res.unserialize();
          $.each(res,function(a,b){
            if (b[0] == 'key') {
              subscription = b[1];
            }  
          });
          append_to_log("monitoring", "id", subscription);
          var Socket = "MozWebSocket" in window ? MozWebSocket : WebSocket;
          if (ws) ws.close();
          ws = new Socket(url.replace(/http/,'ws') + "/notifications/subscriptions/" + subscription + "/ws/");
          ws.onopen = function() {
            append_to_log("monitoring", "opened", "");
          };
          ws.onmessage = function(e) {
            data = $.parseXML(e.data);
            if ($('event > topic',data).length > 0) {
              switch($('event > topic',data).text()) {
                case 'properties/dataelements':
                  monitor_instance_dataelements();
                  break;
                case 'properties/description':
                  monitor_instance_dsl();
                  break;
                case 'properties/endpoints':
                  monitor_instance_endpoints();
                  break;
                case 'properties/state':
                  monitor_instance_state_change(JSON.parse($('event > notification',data).text()).state);
                  break;
                case 'properties/position':
                  monitor_instance_pos_change($('event > notification',data).text());
                  break;
                case 'properties/transformation':
                  monitor_instance_transformation();
                  break;
                case 'running':
                  monitor_instance_running($('event > notification',data).text(),$('event > event',data).text());
                  break;
              }
              append_to_log("event", $('event > topic',data).text() + "/" + $('event > event',data).text(), $('event > notification',data).text());
            }
            if ($('vote > topic',data).length > 0) {
              var notification = $('vote > notification',data).text();
              append_to_log("vote", $('vote > topic',data).text() + "/" + $('vote > vote',data).text(), notification);
              monitor_instance_vote_add(notification);
            }  
          };
          ws.onclose = function() {
            append_to_log("monitoring", "closed", "server down i assume.");
          };
          if (load) load_testset();
        }
      });
*/

//      monitor_instance_endpoints();
//      monitor_instance_transformation();
//      monitor_instance_dsl();
//      monitor_instance_state();

    },
    error: function(a,b,c) {
      alert("This ain't no CPEE instance");
//      ui_tab_click("#tabnew");
    }
  });      
}// }}}

function monitor_instance_dataelements() {// {{{
  var url = $("input[name=current-instance]").val();
  $.ajax({
    type: "GET", 
    url: url + "/tasks",
    dataType: 'xml',
    success: function(res){
      var ctv = $("#dat_dataelements");
      $(res).find('task').each(function(){
        var node = $("#dat_template_pair tr").clone(true);
        $('.pair_name',node).val($(this).attr('id'));
        $('.pair_value',node).val("Task nehmen");
        ctv.append(node);
      });
/*
      var temp_xml = serialize_hash(temp);

      if (temp_xml != save['dataelements']) {
        save['dataelements'] = temp_xml;
        var ctv = $("#dat_dataelements");
        ctv.empty();
        $.each(temp,function(a,b){
          var node = $("#dat_template_pair tr").clone(true);
          $('.pair_name',node).val(a);
          $('.pair_value',node).val(b);
          ctv.append(node);
        });
      }
*/
    },
    error: function(a,b,c){
      alert("Something wrong");
    }
  });      
} // }}}

function monitor_instance_endpoints() {// {{{
  var url = $("input[name=current-instance]").val();
  $.ajax({
    type: "GET", 
    url: url + "/properties/values/endpoints/",
    success: function(res){
      var values = $("value > *",res);
      var temp = {}
      values.each(function(){
        temp[this.nodeName] = $(this).text();
      });
      var temp_xml = serialize_hash(temp);

      if (temp_xml != save['endpoints']) {
        save['endpoints'] = temp_xml;
        var ctv = $("#dat_endpoints");
        ctv.empty();
        $.each(temp,function(a,b){
          var node = $("#dat_template_pair tr").clone(true);
          $('.pair_name',node).val(a);
          $('.pair_value',node).val(b);
          ctv.append(node);
        });
        ctv.append(temp);
      }  
    }
  });
}// }}}

function monitor_instance_dsl() {// {{{
  var url = $("input[name=current-instance]").val();
  $.ajax({
    type: "GET",
    dataType: "text",
    url: url + "/properties/values/dsl/",
    success: function(res){
      if (res != save['dsl']) {
        save['dsl'] = res;
        var ctv = $("#areadsl");
        ctv.empty();

        res = format_code(res,false,true);
        res = res.replace(/activity\s+:([A-Za-z][a-zA-Z0-9_]+)/g,"<span class='activities' id=\"activity-$1\">activity :$1</span>");
        res = res.replace(/activity\s+\[:([A-Za-z][a-zA-Z0-9_]+)([^\]]*\])/g,"<span class='activities' id=\"activity-$1\">activity [:$1$2</span>");

        ctv.append(res);

        $.ajax({
          type: "GET",
          url: url + "/properties/values/dslx/",
          success: function(res){
            graphrealization = new WfAdaptor(CPEE);
            graphrealization.set_svg_container($('#graphcanvas'));
            graphrealization.set_description($(res), true);
            graphrealization.notify = function(svgid) {
              save_description();
              manifestation.events.click(svgid,undefined);
            };
            $('#graphcanvas').redraw();
            $('#graphcolumn div').redraw();

            monitor_instance_pos();
          }
        });
      }
    }
  });
}// }}}

function monitor_instance_state() {// {{{
  var url = $("input[name=current-instance]").val();
  $.ajax({
    type: "GET", 
    url: url + "/properties/values/state/",
    dataType: "text",
    success: function(res){
      monitor_instance_state_change(res);
    }
  });
}// }}}
function monitor_instance_transformation() {// {{{
  var url = $("input[name=current-instance]").val();
  $.ajax({
    type: "GET", 
    url: url + "/properties/values/attributes/modeltype",
    success: function(res){
      $("#currentmodel").text($(res.documentElement).text());
    },
    error: function() {
      $("#currentmodel").text('???');
    }
  });
}// }}}

function monitor_instance_pos() {// {{{
  var url = $("input[name=current-instance]").val();
  $.ajax({
    type: "GET", 
    url: url + "/properties/values/positions/",
    success: function(res){
      var values = $("value > *",res);
      format_visual_clear();
      values.each(function(){
        var what = this.nodeName;
        format_visual_add(what,"passive");
      });
    }
  });
}// }}}

function monitor_instance_running(notification,event) {// {{{
  if (save['state'] == "stopping") return;
  var parts = JSON.parse(notification);
  if (event == "activity_calling")
    format_visual_add(parts.activity,"active")
  if (event == "activity_done")
    format_visual_remove(parts.activity,"active")
} // }}}
function monitor_instance_state_change(notification) { //{{{
  if (notification == "ready" || notification == "stopped" || notification == "running") {
    $("#state button").removeAttr('disabled');
  }  
  if (notification != save['state']) {
    save['state'] = notification;

    var ctv = $("#state");
    ctv.empty();

    if (notification == "stopped") {
      monitor_instance_pos();
    }  
    if (notification == "running") {
      format_visual_clear();
    }  

    var but = "";
    if (notification == "ready" || notification == "stopped") {
      but = " ⇒ <button onclick='$(this).attr(\"disabled\",\"disabled\");start_instance();'>start</button> / <button onclick='$(this).attr(\"disabled\",\"disabled\");sim_instance();'>simulate</button>";
    }
    if (notification == "running") {
      but = " ⇒ <button onclick='$(this).attr(\"disabled\",\"disabled\");stop_instance();'>stop</button>";
    }

    if (notification == "finished") {
      $('.tabbehind button').hide();
    } else {
      $('#parameters .tabbehind button').show();
    }  

    ctv.append(notification + but);
  }
}   //}}}
function monitor_instance_pos_change(notification) {// {{{
  var parts = JSON.parse(notification);
  if (parts['unmark']) {
    $.each(parts['unmark'],function(a,b){
      format_visual_remove(b,"passive") 
    });
  }
  if (parts['at']) {
    $.each(parts['at'],function(a,b){
      format_visual_add(b,"passive") 
    });
  }
} // }}}

function monitor_instance_vote_add(notification) {// {{{
  var parts = JSON.parse(notification);
  var ctv = $("#votes");

  astr = '';
  if ($("input[name=votecontinue]").is(':checked'))
    astr += "<button id='vote_to_continue-" + parts.activity + "-" + parts.callback + "' onclick='$(this).attr(\"disabled\",\"disabled\");monitor_instance_vote_remove(\"" + parts.activity + "\",\"" + parts.callback + "\",\"true\");'>" + parts.activity + "</button>";
  ctv.append(astr);
  format_visual_add(parts.activity,"vote")
}// }}}
