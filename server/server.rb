#!/usr/bin/ruby
require 'pp'
require 'json'
require 'fileutils'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/fileserve'
require 'cpee/redis'
require 'cpee/message'
require 'cpee/persistence'
require 'cpee/attributes_helper'
require 'cpee/implementation_notifications'
require 'cpee/implementation_callbacks'
require 'chronic_duration'
require_relative '../lib/cpee-worklist/worklist'
require_relative '../lib/cpee-worklist/activities'
require_relative '../lib/cpee-worklist/controller'
require_relative '../lib/cpee-worklist/utils'

class ActivityHappens < Riddl::Implementation #{{{
  def response
    controller = @a[0]

    activity = {}
    activity['process'] = @h.keys.include?('CPEE_ATTR_INFO') ? "#{@h['CPEE_ATTR_INFO']} (#{@h['CPEE_INSTANCE'].split('/').last})" : "DUMMY PROCESS (#{@h['CPEE_INSTANCE'].split('/').last})"
    activity['label'] = @h.keys.include?('CPEE_INSTANCE') ? "#{@h['CPEE_LABEL']}" : 'DUMMY LABEL'
    activity['user'] = []
    activity['url'] = @h['CPEE_CALLBACK']
    activity['id']  = @h['CPEE_CALLBACK_ID']

    activity['cpee_activity_id'] = @h['CPEE_ACTIVITY']
    activity['cpee_base'] = @h['CPEE_BASE']
    activity['cpee_instance'] = @h['CPEE_INSTANCE']

    activity['uuid'] = @h['CPEE_ATTR_UUID']

    omo = @p.shift.value
    activity['orgmodel'] = @h[ 'CPEE_ATTR_' + omo.upcase] || omo

    activity['form'] = @p.shift.value
    activity['unit'] = @p.first.name == 'unit' ? @p.shift.value : '*'
    activity['role'] = @p.first.name == 'role' ? @p.shift.value : '*'
    activity['priority'] = @p.first.name == 'priority' ? @p.shift.value.to_i : 1
    activity['collect'] = @p.first.name == 'collect' ? @p.shift.value.to_i : nil
    activity['deadline'] = @p.first.name == 'deadline' ? ((Time.now + ChronicDuration.parse(@p.shift.value)) rescue nil): nil
    activity['restrictions'] = []
    rests = JSON::parse(@p.shift.value) rescue nil
    activity['restrictions'] << rests unless rests.nil?
    activity['parameters'] = JSON::parse(@p.shift.value) rescue {}
    status, content, headers = Riddl::Client.new(activity['orgmodel']).get
    if status == 200
      begin
        xml =  content[0].value.read
        schema = XML::Smart.open(@a[0].opts[:ORG_SCHEMA])
        org_xml = XML::Smart.string(xml)
        raise 'a fucked up xml (wink wink)' unless org_xml.validate_against(schema)
        org_xml.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
      rescue => e
        puts e.message
        puts e.backtrace
        @a[0].notify('task/invalid', :callback_id => activity['id'], :reason => 'orgmodel invalid', :instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'] )
        @status = 404
        return
      end
      attributes = ""
      if activity['role'] != '*'
        attributes += "@role='#{activity['role']}'"
        attributes += " and " if activity['unit'] != '*'
      end
      attributes += "@unit='#{activity['unit']}'" if activity['unit'] != '*'
      user = org_xml.find("/o:organisation/o:subjects/o:subject[o:relation[#{attributes}]]").map{ |e| e.attributes['uid'] }

      if user.empty?
        @a[0].notify('task/invalid', :callback_id => activity['id'], :reason => 'no users found for this combination of unit/role',:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'] )
        @status = 404
        return
      end
      @a[0].add_activity activity
      @a[0].add_orgmodel Riddl::Protocols::Utils::escape(activity['orgmodel']), xml
      Thread.new do
        # TODO immediate vote for adding by external subscribers
        # results = @a[0].vote('task/add', :user => user ,                                      :instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'] )
        # if (results.length == 1) && (user.include? results[0])
        #   activity['user'] = results[0]
        #   info = user_info(@a[0].opts,activity,activity['user'])
        #   @a[0].notify('task/add',       :user => user,:callback_id => activity['id'],        :instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :wl_instance => activity['wl_instance'] )
        #   @a[0].notify('user/take',      :user => results[0], :callback_id => activity['id'], :instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :organisation => info, :wl_instance => activity['wl_instance'])
        # else
        @a[0].notify('task/add', :user => user,:callback_id => activity['id'], :instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'])
        # end
      end
      @headers << Riddl::Header.new('CPEE_CALLBACK','true')
    else
      @status = 404
    end
  end
end #}}}

class TaskDel < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |e| e["id"] == @r.last }
    if index
      activity = @a[0].activities[index]
      if activity['collect'] && activity['collect'] > 1
        activity['collect'] -= 1
        activity['restrictions'] << { "restriction" => { "mode" => "prohibit", "id" => @r[-3] } }
        @a[0].activities.serialize
        @a[0].notify('user/finish', :callback_id => activity['id'], :user => @r[-3], :role => activity['role'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'])
      else
        activity = @a[0].activities.delete_at(index)
        @a[0].activities.serialize
        if @r.length == 3
          @a[0].notify('task/delete', :callback_id => activity['id'],                                             :instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'])
          Riddl::Client.new(activity['url']).put
        else
          info = user_info(@a[0].opts,activity,@r[-3])
          @a[0].notify('user/finish', :callback_id => activity['id'], :user => @r[-3], :role => activity['role'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'])
        end
      end
    else
      @status = 404
    end
  end
end  #}}}

class ShowTasks < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    umodels = @a[0].orgmodels.map do |fname|
      doc = XML::Smart.open_unprotected(File.join(@a[0].opts[:top],'orgmodels',fname))
      doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
      doc
    end
    @a[0].activities.each do |activity|
      x = out.root.add "task", :callback_id => activity['id'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :instance_uuid => activity['uuid'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel']
      x.add "process" , activity['process']
      x.add "label" , activity['label']
      x.add "role" , activity['role']
      x.add "unit" , activity['unit']

      if activity['user'].any?
        umodels.each do |doc|
          activity['user'].each do |user|
            if user = doc.find("/o:organisation/o:subjects/o:subject[@uid='#{user}']").first
              x.add "user", user.attributes['id'], :uid => user.attributes['uid']
              break
            end
          end
        end
      else
        xpath = ''
        xpath = "[@role='#{activity['role']}' and @unit='#{activity['unit']}']" if (activity['unit'] != '*' && activity['role'] != '*' )
        xpath = "[@role='#{activity['role']}']" if (activity['unit'] == '*' && activity['role'] != '*' )
        xpath = "[@unit='#{activity['unit']}']" if (activity['unit'] != '*' && activity['role'] == '*' )

        umodels.each do |doc|
          if (tmp = doc.find("/o:organisation/o:subjects/o:subject[o:relation#{xpath}]")).length > 0
            tmp.each{|e| x.add "user", e.attributes['id'], :uid => e.attributes['uid'] }
          end
        end
      end
    end
    Riddl::Parameter::Complex.new("tasks","text/xml", out.to_s)
  end
end  #}}}

 class ShowUserTasks < Riddl:: Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    tasks = {}
    @a[0].orgmodels.each do |e|
      XML::Smart.open(File.join(@a[0].opts[:top],'orgmodels',e)) do |doc|
        doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
        doc.find("/o:organisation/o:subjects/o:subject[@uid='#{@r[-2]}']/o:relation").each do |rel|
          @a[0].activities.each do |activity|
            restrict = false
            activity['restrictions'].each do |restriction|
              restrict = true if restriction['restriction']['mode'] == 'prohibit' && restriction['restriction']['id'] == @r[-2]
            end
            if (
                 activity['role']=='*' ||
                 activity['role'].casecmp(rel.attributes['role']) == 0
               ) && (
                 activity['unit'] == '*' ||
                 activity['unit'].casecmp(rel.attributes['unit']) == 0
               ) && (
                 activity['collect'] ||
                 activity['user'].empty? ||
                 activity['user'].include?(@r[-2])
               ) && !restrict
              tasks["#{activity['id']}"] = { :all => activity.has_key?('collect') && !activity['collect'].nil?, :uid => @r[-2], :priority => activity['priority'], :label => activity['process'] + ': ' + activity['label'] }
              tasks["#{activity['id']}"][:deadline] = activity['deadline'] if activity['deadline']
            end
          end
        end
      end
    end
    tasks.sort_by{ |k,e| e[:priority] }.each{|k,v| out.root.add("task", v.merge(:id => k))}
    x = Riddl::Parameter::Complex.new("return","text/xml") do
      out.to_s
    end
    x
  end
end  #}}}

class TaskTake < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |c| c["id"] == @r.last }
    if index
      activity = @a[0].activities[index]
      activity['user'].push @r[-3]if user_ok(@a[0].opts,activity,@r[-3])
      info = user_info(@a[0].opts,activity,@r[-3])
      @a[0].activities.serialize
      @a[0].notify('user/take', :user => @r[-3], :callback_id => activity['id'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'],:instance_uuid => activity['uuid'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :organisation => info)
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE-UPDATE','true'),
        Riddl::Header.new('CPEE-STATUS','take'),
        Riddl::Header.new('CPEE-EVENT','take')
      ]
    else
      @status = 404
    end
  end
end  #}}}

class TaskGiveBack < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |c| c["id"] == @r.last }
    if index && (@a[0].activities[index]['user'] == @r[-3])
      activity = @a[0].activities[index]
      activity['user'] = []
      callback_id = @a[0].activities[index]['id']
      @a[0].activities.serialize
      @a[0].notify('user/giveback', :callback_id => activity['id'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'],:instance_uuid => activity['uuid'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'])
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE-UPDATE','true'),
        Riddl::Header.new('CPEE-STATUS','giveback'),
        Riddl::Header.new('CPEE-EVENT','giveback')
      ]
    else
      @status = 404
    end
  end
end  #}}}

class TaskDetails < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |c| c["id"] == @r.last }
    if index
      Riddl::Parameter::Complex.new "data","application/json", JSON.generate({:collect => @a[0].activities[index].has_key?('collect') && !@a[0].activities[index]['collect'].nil?, 'url' => @a[0].activities[index]['url'], 'form' => @a[0].activities[index]['form'], 'parameters' => @a[0].activities[index]['parameters'], 'label' => @a[0].activities[index]['label']})
    else
      @status = 404
    end
  end
end  #}}}

class GetOrgModels < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<orgmodels/>')
    @a[0].orgmodels.each{|e| out.root.add("orgmodel", e)}
    Riddl::Parameter::Complex.new "return","text/xml", out.to_s
  end
end #}}}

class AssignTask < Riddl::Implementation #{{{
  def response
   index = @a[0].activities.index{ |c| c["id"] == @r.last }
    if index
      user = @p[0].value
      @a[0].activities[index]["user"] = user if user_ok(@a[0].opts,@a[0].activities[index],user)
      callback_id = @a[0].activities[index]['id']
      info = user_info(@a[0].opts,@a[0].activities[index],user)
      @a[0].activities.serialize
      @a[0].notify('user/take', :index => callback_id, :user => @p[0].value, :organisation => info)
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE-UPDATE','true'),
        Riddl::Header.new('CPEE-STATUS','take'),
        Riddl::Header.new('CPEE-EVENT','take')
      ]
    else
      @status = 404
    end
  end
end  #}}}

Riddl::Server.new(Worklist::SERVER, :port => 9398) do |opts|
  accessible_description true
  cross_site_xhr true

  opts[:ORG_SCHEMA] = ::File.join(__dir__, 'organisation.rng')
  opts[:top] = ::File.join(__dir__, 'data')
  opts[:topics] = ::File.join(__dir__, 'topics.xml')

  opts[:watchdog_frequency]         ||= 7
  opts[:watchdog_start_off]         ||= false

  ### set redis_cmd to nil if you want to do global
  ### at least redis_path or redis_url and redis_db have to be set if you do global
  opts[:redis_path]                 ||= 'redis.sock' # use e.g. /tmp/redis.sock for global stuff. Look it up in your redis config
  opts[:redis_db]                   ||= 0
  ### optional redis stuff
  opts[:redis_url]                  ||= nil
  opts[:redis_cmd]                  ||= 'redis-server --port 0 --unixsocket #redis_path# --unixsocketperm 600 --pidfile #redis_pid# --dir #redis_db_dir# --dbfilename #redis_db_name# --databases 1 --save 900 1 --save 300 10 --save 60 10000 --rdbcompression yes --daemonize yes'
  opts[:redis_pid]                  ||= 'redis.pid' # use e.g. /var/run/redis.pid if you do global. Look it up in your redis config
  opts[:redis_db_name]              ||= 'redis.rdb' # use e.g. /var/lib/redis.rdb for global stuff. Look it up in your redis config

  controller = Worklist::Controller.new(opts)

  CPEE::redis_connect opts, 'Server Main'

  opts[:sse_keepalive_frequency]    ||= 10
  opts[:sse_connections]            = {}
  CPEE::Message::set_workers(1)

  parallel do
    Worklist::watch_services(opts[:watchdog_start_off],opts[:redis_url],File.join(opts[:basepath],opts[:redis_path]),opts[:redis_db])
    EM.add_periodic_timer(opts[:watchdog_frequency]) do ### start services
      Worklist::watch_services(opts[:watchdog_start_off],opts[:redis_url],File.join(opts[:basepath],opts[:redis_path]),opts[:redis_db])
    end
    EM.defer do ### catch all sse connections
      CPEE::Notifications::sse_distributor(opts)
    end
    EM.add_periodic_timer(opts[:sse_keepalive_frequency]) do
      CPEE::Notifications::sse_heartbeat(opts)
    end
  end

  cleanup do
    Worklist::cleanup_services(opts[:watchdog_start_off])
  end

  interface 'main' do
    run ActivityHappens,controller if post 'activityhappens'
    run ShowTasks,controller if get
    on resource 'callbacks' do
      use CPEE::Callbacks::implementation(opts)
    end
    on resource 'orgmodels' do
      run GetOrgModels, controller if get
    end
    on resource 'tasks' do
      on resource do
        run AssignTask,controller if put 'uid'
        run TaskDel,controller if delete
      end
    end
    on resource do
      on resource 'tasks' do
        run ShowUserTasks,controller if get
        on resource do |r|
          run TaskDetails,controller if get
          run TaskTake,controller if put 'take'
          run TaskGiveBack,controller if put 'giveback'
          run TaskDel,controller if delete
        end
      end
    end
  end

  interface 'notifications' do |r|
    use CPEE::Notifications::implementation('worklist',opts)
  end

end.loop!
