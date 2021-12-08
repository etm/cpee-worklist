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
require_relative '../lib/cpee-worklist/worklist'
require_relative '../lib/cpee-worklist/activities'
require_relative '../lib/cpee-worklist/controller'
require_relative '../lib/cpee-worklist/utils'

class ActivityHappens < Riddl::Implementation #{{{
  def response
    controller = @a[0]

    activity = {}
    activity['label'] = @h.keys.include?('CPEE_INSTANCE') ? "#{@h['CPEE_LABEL']} (#{@h['CPEE_INSTANCE'].split('/').last})" : "DUMMY LABEL"
    activity['user'] = '*'
    activity['url'] = @h['CPEE_CALLBACK']
    activity['id']  = @h['CPEE_CALLBACK'].split('/').last

    activity['cpee_activity_id'] = @h['CPEE_ACTIVITY']
    activity['cpee_base'] = @h['CPEE_BASE']
    activity['cpee_instance'] = @h['CPEE_INSTANCE']

    activity['uuid'] = @h['CPEE_ATTR_UUID']

    omo = @p.shift.value
    activity['orgmodel'] = @h[ 'CPEE_ATTR_' + omo.upcase] || omo

    dom = @p.shift.value
    domain = activity['domain'] = @h[ 'CPEE_ATTR_' + dom.upcase] || dom

    activity['wl_instance'] = "#{controller.opts[:url]}/#{domain}"

    activity['form'] = @p.shift.value
    activity['unit'] = @p.first.name == 'unit' ? @p.shift.value : '*'
    activity['role'] = @p.first.name == 'role' ? @p.shift.value : '*'
    activity['parameters'] = @p.shift.value rescue '[]'
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
        @a[0][domain].notify('task/invalid', :callback_id => activity['id'], :reason => 'orgmodel invalid',:domain => activity['domain'], :instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'] ) if @a[0].keys.include? domain
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
        @a[0][domain].notify('task/invalid', :callback_id => activity['id'], :reason => 'no users found for this combination of unit/role',:domain => activity['domain'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'] ) if @a[0].keys.include? domain
        @status = 404
        return
      end
      @a[0].add_activity domain, activity
      @a[0][domain].add_orgmodel Riddl::Protocols::Utils::escape(activity['orgmodel']), xml
      Thread.new do
        # TODO immediate vote for adding by external subscribers
        # results = @a[0][domain].vote('task/add', :user => user ,                                      :domain => activity['domain'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'] )
        # if (results.length == 1) && (user.include? results[0])
        #   activity["user"] = results[0]
        #   info = user_info(activity,activity["user"])
        #   @a[0][domain].notify('task/add',       :user => user,:callback_id => activity['id'],        :domain => activity['domain'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :wl_instance => activity['wl_instance'] )
        #   @a[0][domain].notify('user/take',      :user => results[0], :callback_id => activity['id'], :domain => activity['domain'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :organisation => info, :wl_instance => activity['wl_instance'])
        # else
        @a[0][domain].notify('task/add',       :user => user,:callback_id => activity['id'],        :domain => activity['domain'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :wl_instance => activity['wl_instance']) if @a[0].keys.include? domain
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

      activity = @a[0].activities.delete_at(index)
      @a[0].activities.serialize
      if @r.length == 3
        @a[0].notify('task/delete', :callback_id => activity['id'],                                                      :domain => activity['domain'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'],:wl_instance => activity['wl_instance'])
        Riddl::Client.new(activity['url']).put
      else
        info = user_info(activity,activity['user'])
        @a[0].notify('user/finish', :callback_id => activity['id'], :user => activity['user'], :role => activity['role'],:domain => activity['domain'],:instance_uuid => activity['uuid'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :organisation => info, :wl_instance => activity['wl_instance'])
      end
    else
      @status = 404
    end
  end
end  #}}}

class Show_Domains < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<domains/>')
    @a[0].keys.each { |x| out.root.add('domain', :name=> x)}
    Riddl::Parameter::Complex.new("domains","text/xml") do
      out.to_s
    end
  end
end  #}}}

class Show_Domain_Tasks < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    @a[0].orgmodels.each do |fname|
      doc = XML::Smart.open(File.dirname(__FILE__) + "/domains/#{Riddl::Protocols::Utils::unescape(@r.last)}/orgmodels/#{fname}")
      doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
      @a[0].activities.each do |activity|
        x = out.root.add "task", :callback_id => activity['id'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'], :cpee_base => activity['cpee_base'],:instance_uuid => activity['uuid'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel']
        x.add "label" , activity['label']
        x.add "role" , activity['role']
        x.add "unit" , activity['unit']

        if activity['user']!='*'
          user = doc.find("/o:organisation/o:subjects/o:subject[@uid='#{activity['user']}']").first
          x.add "user", user.attributes['id'], :uid => user.attributes['uid']
        else

          xpath = ''
          xpath = "[@role='#{activity['role']}' and @unit='#{activity['unit']}']" if (activity['unit'] != '*' && activity['role'] != '*' )
          xpath = "[@role='#{activity['role']}']" if (activity['unit'] == '*' && activity['role'] != '*' )
          xpath = "[@unit='#{activity['unit']}']" if (activity['unit'] != '*' && activity['role'] == '*' )

          doc.find("/o:organisation/o:subjects/o:subject[o:relation#{xpath}]").each{|e| x.add "user", e.attributes['id'], :uid => e.attributes['uid'] }
        end
      end
    end
    Riddl::Parameter::Complex.new("domain_tasks","text/xml", out.to_s)
  end
end  #}}}

class Show_Tasks < Riddl:: Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    tasks = {}
    @a[0].orgmodels.each do |e|
      XML::Smart.open("domains/#{@a[0].domain}/orgmodels/#{e}") do |doc|
        doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
        doc.find("/o:organisation/o:subjects/o:subject[@uid='#{@r[-2]}']/o:relation").each do |rel|
          @a[0].activities.each do |activity|
            if (activity['role']=='*' || activity['role'].casecmp(rel.attributes['role']) == 0) && (activity['unit'] == '*' || activity['unit'].casecmp(rel.attributes['unit']) == 0) && (activity['user']=='*' || activity['user']==@r[-2])
              tasks["#{activity['id']}"] = {:uid => activity['user'], :label => activity['label'] }
            end
          end
        end
      end
    end
    tasks.each{|k,v| out.root.add("task", :id => k, :uid => v[:uid], :label => v[:label])}
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
      activity["user"] = @r[-3]	if user_ok(activity,@r[-3])
      info = user_info(activity,@r[-3])
      @a[0].activities.serialize
      @a[0].notify('user/take', :user => @r[-3], :callback_id => activity['id'], :domain => activity['domain'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'],:instance_uuid => activity['uuid'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :organisation => info, :wl_instance => activity['wl_instance'])
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE-UPDATE','true'),
        Riddl::Header.new('CPEE-UPDATE-STATUS','take')
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
      activity["user"] = '*'
      callback_id = @a[0].activities[index]['id']
      @a[0].activities.serialize
      @a[0].notify('user/giveback', :callback_id => activity['id'], :domain => activity['domain'], :cpee_callback => activity['url'], :cpee_instance => activity['cpee_instance'],:instance_uuid => activity['uuid'], :cpee_base => activity['cpee_base'], :cpee_label => activity['label'], :cpee_activity => activity['cpee_activity_id'], :orgmodel => activity['orgmodel'], :wl_instance => activity['wl_instance'])
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE-UPDATE','true'),
        Riddl::Header.new('CPEE-UPDATE-STATUS','giveback')
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
      Riddl::Parameter::Complex.new "data","application/json", JSON.generate({'url' => @a[0].activities[index]['url'], 'form' => @a[0].activities[index]['form'], 'parameters' => @a[0].activities[index]['parameters'], 'label' => @a[0].activities[index]['label']})
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
      @a[0].activities[index]["user"] = user if user_ok(@a[0].activities[index],user)
      callback_id = @a[0].activities[index]['id']
      info = user_info(@a[0].activities[index],user)
      @a[0].activities.serialize
      @a[0].notify('user/take', :index => callback_id, :user => @p[0].value, :organisation => info)
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE-UPDATE','true'),
        Riddl::Header.new('CPEE-UPDATE-STATUS','take')
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
  opts[:top] = ::File.join(__dir__, 'domains')
  opts[:domains] = ::File.join(__dir__, 'domains','*')
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
    run Show_Domains,controller if get
    on resource "[a-zA-Z0-9]+" do |r|
      domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
      domain = Riddl::Protocols::Utils::unescape(domain)
      if controller.keys.include? domain
        run Show_Domain_Tasks,controller[domain] if get
        on resource 'callbacks' do
          use CPEE::Callbacks::implementation(domain, opts)
        end
        on resource 'orgmodels' do
          run GetOrgModels, controller[domain] if get
        end
        on resource 'tasks' do
          on resource do
            run AssignTask,controller[domain] if put 'uid'
            run TaskDel,controller[domain] if delete
          end
        end
        on resource do
          on resource 'tasks' do
            run Show_Tasks,controller[domain] if get
            on resource do |r|
              run TaskDetails,controller[domain] if get
              run TaskTake,controller[domain] if put 'take'
              run TaskGiveBack,controller[domain] if put 'giveback'
              run TaskDel,controller[domain] if delete
            end
          end
        end
      end
    end
  end

  interface 'notifications' do |r|
    domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
    domain = Riddl::Protocols::Utils::unescape(domain)
    use CPEE::Notifications::implementation(domain, opts)
  end

end.loop!
